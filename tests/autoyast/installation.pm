# Copyright (C) 2015-2017 SUSE Linux GmbH
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Autoyast installation
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use strict;
use base 'y2logsstep';
use testapi;
use utils;
use power_action_utils 'prepare_system_shutdown';
use version_utils qw(is_sle is_caasp is_released);

my $confirmed_licenses = 0;
my $stage              = 'stage1';
my $maxtime            = 2000 * get_var('TIMEOUT_SCALE', 1);    #Max waiting time for stage 1
my $check_time         = 50;                                    #Period to check screen during stage 1 and 2

# Downloading updates takes long time
$maxtime = 5500 if is_caasp('qam');
# Full install with updates can take extremely long time
$maxtime = 5500 * get_var('TIMEOUT_SCALE', 1) if is_released;


sub accept_license {
    send_key $cmd{accept};
    $confirmed_licenses++;
    # Prevent from matching previous license
    wait_screen_change {
        send_key $cmd{next};
    };
}

sub save_and_upload_stage_logs {
    my $i = shift;
    select_console 'install-shell2', tags => 'install-shell';
    # save_y2logs is not present
    assert_script_run "tar czf /tmp/logs-stage.tar.bz2 /var/log";
    upload_logs "/tmp/logs-stage1-error$i.tar.bz2";
}

sub upload_autoyast_profile {
    my ($self) = @_;
    select_console 'install-shell';
    # the network may be down with keep_install_network=false
    # use static ip in that case if not on s390x
    if (!check_var("BACKEND", "s390x")) {
        type_string " if ! ping -c 1 10.0.2.2 ; then
            ip addr add 10.0.2.200/24 dev eth0
            ip link set eth0 up
            route add default gw 10.0.2.2
        fi
        ";
    }
    # Upload autoyast profile if file exists
    if (script_run '! test -e /tmp/profile/autoinst.xml') {
        upload_logs '/tmp/profile/autoinst.xml';
    }
    # Upload modified profile if pre-install script uses this feature
    if (script_run '! test -e /tmp/profile/modified.xml') {
        upload_logs '/tmp/profile/modified.xml';
    }
    save_screenshot;
    clear_console;
    select_console 'installation';
}

sub handle_expected_errors {
    my ($self, %args) = @_;
    my $i = $args{iteration};
    record_info('Expected error', 'Iteration = ' . $i);
    send_key "alt-s";    #stop
    select_console 'install-shell';
    $self->save_upload_y2logs(suffix => "-$stage-expected_error$i");
    select_console 'installation';
    $i++;
    wait_screen_change { send_key 'tab' };    #continue
    wait_screen_change { send_key 'ret' };
}

sub handle_warnings {
    die "Unknown popup message" unless check_screen('autoyast-known-warning', 0);

    # if VERIFY_TIMEOUT check that message disappears, by default we now have
    # all timeouts set to 0, to verify each warning as they may get missed if have timeout
    if (get_var 'AUTOYAST_VERIFY_TIMEOUT') {
        # Wait until popup disappears
        die "Popup message without timeout" unless wait_screen_change { sleep 11 };
    }
    else {
        # No timeout on warning mesasge, press ok
        wait_screen_change { send_key $cmd{ok} };
    }
}

sub verify_timeout_and_check_screen {
    my ($timer, $needles) = @_;
    if ($timer > $maxtime) {
        #Try to assert_screen to explicitly show mismatching needles
        assert_screen $needles;
        #Die explicitly in case of infinite loop when we match some needle
        die "timeout hit on during $stage";
    }
    return check_screen $needles, $check_time;
}

sub run {
    my ($self) = @_;

    if (check_var('BACKEND', 'ipmi') && get_var("SES5_DEPLOY")) {
        assert_screen 'installation-done', 750;
        reset_consoles;
        select_console 'sol', await_console => 0;
        assert_screen 'prague-pxe-menu', 400;
        send_key 'ret';    # boot from hard disk
        return;
    }
    my @needles           = qw(bios-boot nonexisting-package reboot-after-installation linuxrc-install-fail scc-invalid-url warning-pop-up autoyast-boot);
    my $expected_licenses = get_var('AUTOYAST_LICENSE');
    push @needles, 'autoyast-confirm'        if get_var('AUTOYAST_CONFIRM');
    push @needles, 'autoyast-postpartscript' if get_var('USRSCR_DIALOG');
    # bios-boot needle does not match if worker stalls during boot - poo#28648
    push @needles, 'linux-login-casp' if is_caasp;
    # Autoyast reboot automatically without confirmation, usually assert 'bios-boot' that is not existing on zVM
    # So push a needle to check upcoming reboot on zVM that is a way to indicate the stage done
    push @needles, 'autoyast-stage1-reboot-upcoming' if check_var('ARCH', 's390x');
    # Import untrusted certification for SMT
    push @needles, 'untrusted-ca-cert' if get_var('SMT_URL');
    # Workaround for removing package error during upgrade
    push(@needles, 'ERROR-removing-package') if get_var("AUTOUPGRADE");
    # If it's beta, we may match license screen before pop-up shows, so check for pop-up first
    if (get_var('BETA')) {
        push(@needles, 'inst-betawarning');
    }
    elsif ($expected_licenses) {
        push(@needles, 'autoyast-license');
    }

    # Kill ssh proactively before reboot to avoid half-open issue on zVM, do not need this on zKVM
    prepare_system_shutdown if check_var('BACKEND', 's390x');
    my $postpartscript = 0;
    my $confirmed      = 0;

    my $i          = 1;
    my $num_errors = 0;
    my $timer      = 0;    # Prevent endless loop

    check_screen \@needles, $check_time;
    until (match_has_tag('reboot-after-installation')
          || match_has_tag('bios-boot')
          || match_has_tag('autoyast-stage1-reboot-upcoming')
          || match_has_tag('linux-login-casp'))
    {
        #Verify timeout and continue if there was a match
        next unless verify_timeout_and_check_screen(($timer += $check_time), \@needles);
        if (match_has_tag('autoyast-boot')) {
            send_key 'ret';    # press enter if grub timeout is disabled, like we have in reinstall scenarios
            last;              # if see grub, we get to the second stage, as it appears after bios-boot which we may miss
        }
        #repeat until timeout or login screen
        elsif (match_has_tag('nonexisting-package')) {
            @needles = grep { $_ ne 'nonexisting-package' } @needles;
            $self->handle_expected_errors(iteration => $i);
            $num_errors++;
        }
        elsif (match_has_tag('warning-pop-up')) {
            # Softfail only on sle, as timeout is there on CaaSP
            if (is_sle && check_screen('warning-partition-reduced', 0)) {
                # See poo#19978, no timeout on partition warning, hence need to click OK button to soft-fail
                record_info('bsc#1045470',
                    "There is no timeout on sle for reduced partition screen by default.\n"
                      . "But there is timeout on CaaSP and if explicitly defined in profile. See bsc#1045470 for details.");
                send_key_until_needlematch 'create-partition-plans-finished', $cmd{ok};
                next;
            }
            # Process warnings
            handle_warnings;
        }
        elsif (match_has_tag('scc-invalid-url')) {
            die 'Fix invalid SCC reg URL https://trello.com/c/N09TRZxX/968-3-don-t-crash-on-invalid-regurl-on-linuxrc-commandline';
        }
        elsif (match_has_tag('linuxrc-install-fail')) {
            save_and_upload_stage_logs($i);
            die "installation ends in linuxrc";
        }
        elsif (match_has_tag('autoyast-confirm')) {
            # select network (second entry)
            send_key "ret";

            assert_screen("startinstall", 20);

            wait_screen_change { send_key 'tab' };
            wait_screen_change { send_key 'ret' };
            @needles = grep { $_ ne 'autoyast-confirm' } @needles;
            $confirmed = 1;
        }
        elsif (match_has_tag('autoyast-license')) {
            accept_license;
            # In SLE 12 we have BETA warning shown for each addon
            push(@needles, 'inst-betawarning') if --$expected_licenses;
        }
        elsif (match_has_tag('inst-betawarning')) {
            wait_screen_change { send_key $cmd{ok} };
            @needles = grep { $_ ne 'inst-betawarning' } @needles;
            push(@needles, 'autoyast-license') if $expected_licenses;
            next;
        }
        elsif (match_has_tag('untrusted-ca-cert')) {
            send_key 'alt-t';
            wait_still_screen 5;
            next;
        }
        elsif (match_has_tag('ERROR-removing-package')) {
            send_key 'alt-i';    # ignore
            assert_screen 'WARNING-ignoring-package-failure';
            send_key 'alt-o';
            next;
        }
        elsif (match_has_tag('autoyast-postpartscript')) {
            @needles = grep { $_ ne 'autoyast-postpartscript' } @needles;
            $postpartscript = 1;
        }
        elsif (match_has_tag('autoyast-error')) {
            die 'Error detected during first stage of the installation';
        }
    }

    if (get_var("USRSCR_DIALOG")) {
        die "usrscr dialog" if !$postpartscript;
    }

    if (get_var("AUTOYAST_CONFIRM")) {
        die "autoyast_confirm" if !$confirmed;
    }

    if (get_var("AUTOYAST_LICENSE")) {
        if ($confirmed_licenses == 0 || $confirmed_licenses != get_var("AUTOYAST_LICENSE", 0)) {
            die "Autoyast License shown: $confirmed_licenses, but expected: " . get_var('AUTOYAST_LICENSE') . " time(s)";
        }
    }

    # We use startshell boot option on s390x to sync actions with reboot, normally is not used
    # Cannot verify second stage properly on s390x, so recoonect to already installed system
    if (check_var('ARCH', 's390x')) {
        reconnect_mgmt_console(timeout => 500);
        return;
    }

    # CaaSP does not have second stage
    return if is_caasp;
    # Second stage starts here
    $maxtime = 1000;
    $timer   = 0;
    $stage   = 'stage2';

    check_screen \@needles, $check_time;
    @needles = qw(reboot-after-installation autoyast-postinstall-error autoyast-boot warning-pop-up autoyast-error);
    until (match_has_tag 'reboot-after-installation') {
        #Verify timeout and continue if there was a match
        next unless verify_timeout_and_check_screen(($timer += $check_time), \@needles);
        if (match_has_tag('autoyast-postinstall-error')) {
            $self->handle_expected_errors(iteration => $i);
            $num_errors++;
        }
        elsif (match_has_tag('autoyast-boot')) {
            # if we matched bios-boot tag during stage1 we may get grub menu, legacy behavior
            # keep it as a fallback if grub timeout is disabled
            send_key 'ret';
        }
        elsif (match_has_tag('warning-pop-up')) {
            handle_warnings;    # Process warnings during stage 2
        }
        elsif (match_has_tag('autoyast-error')) {
            die 'Error detected during second stage of the installation';
        }
    }

    my $expect_errors = get_var('AUTOYAST_EXPECT_ERRORS') // 0;
    die 'exceeded expected autoyast errors' if $num_errors != $expect_errors;
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    $self->upload_autoyast_profile;
    $self->SUPER::post_fail_hook;
}

1;
