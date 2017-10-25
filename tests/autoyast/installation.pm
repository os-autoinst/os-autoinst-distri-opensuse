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
use base "opensusebasetest";
use testapi;
use utils;

my $confirmed_licenses = 0;
my $stage              = 'stage1';
my $maxtime            = 2000 * get_var('TIMEOUT_SCALE', 1);    #Max waiting time for stage 1
my $check_time         = 50;                                    #Period to check screen during stage 1 and 2

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

sub save_and_upload_yastlogs {
    my ($self, $suffix) = @_;
    my $name = $stage . $suffix;
    # save logs and continue
    select_console 'install-shell';

    # the network may be down with keep_install_network=false
    # use static ip in that case
    type_string "
      save_y2logs /tmp/y2logs-$name.tar.bz2
      if ! ping -c 1 10.0.2.2 ; then
        ip addr add 10.0.2.200/24 dev eth0
        ip link set eth0 up
        route add default gw 10.0.2.2
      fi
    ";
    upload_logs "/tmp/y2logs-$name.tar.bz2";
    $self->save_and_upload_log('btrfs filesystem usage /mnt', 'btrfs-filesystem-usage-mnt.txt');
    $self->save_and_upload_log('df',                          'df.txt');
    save_screenshot;
    clear_console;
    select_console 'installation';
}

sub handle_expected_errors {
    my ($self, %args) = @_;
    my $i = $args{iteration};
    record_info('Expected error', 'Iteration = ' . $i);
    send_key "alt-s";    #stop
    $self->save_and_upload_yastlogs("_expected_error$i");
    $i++;
    wait_screen_change { send_key 'tab' };    #continue
    wait_screen_change { send_key 'ret' };
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
    my @needles
      = qw(bios-boot nonexisting-package reboot-after-installation linuxrc-install-fail scc-invalid-url warning-pop-up inst-betawarning autoyast-boot);
    push @needles, 'autoyast-confirm'        if get_var('AUTOYAST_CONFIRM');
    push @needles, 'autoyast-postpartscript' if get_var('USRSCR_DIALOG');

    my $postpartscript = 0;
    my $confirmed      = 0;

    my $i          = 1;
    my $num_errors = 0;
    my $timer      = 0;    # Prevent endless loop

    mouse_hide(1);
    check_screen \@needles, $check_time;
    until (match_has_tag('reboot-after-installation') || match_has_tag('bios-boot')) {
        #Verify timeout and continue if there was a match
        next unless verify_timeout_and_check_screen(($timer += $check_time), \@needles);
        if (match_has_tag('autoyast-boot')) {
            send_key 'ret';    # grub timeout is disable, so press any key is needed to pass the grub
        }
        #repeat until timeout or login screen
        elsif (match_has_tag('nonexisting-package')) {
            @needles = grep { $_ ne 'nonexisting-package' } @needles;
            $self->handle_expected_errors(iteration => $i);
            $num_errors++;
        }
        elsif (match_has_tag('warning-pop-up')) {
            # Softfail only on sle, as timeout is there on CaaSP
            if (check_var('DISTRI', 'sle') && check_screen('warning-partition-reduced', 0)) {
                # See poo#19978, no timeout on partition warning, hence need to click OK button to soft-fail
                record_info('bsc#1045470',
                        "There is no timeout on sle for reduced partition screen by default.\n"
                      . "But there is timeout on CaaSP and if explicitly defined in profile. See bsc#1045470 for details.");
                send_key_until_needlematch 'create-partition-plans-finished', $cmd{ok};
                next;
            }
            if (match_has_tag('bsc#1055034') || match_has_tag('bsc#1054895')) {
                record_soft_failure('bsc#1055034');
                if (check_screen 'bsc#1054895', 0) {
                    record_soft_failure('bsc#1054895');
                }
                send_key $cmd{ok};
                next;
            }
            if (match_has_tag('bsc#1056356')) {
                record_soft_failure('bsc#1056356');
                send_key $cmd{ok};
                next;
            }
            if (match_has_tag('bsc#1058099')) {
                record_soft_failure('bsc#1058099');
                send_key $cmd{ok};
                next;
            }
            if (match_has_tag('bsc#1058999')) {
                record_soft_failure('bsc#1058999');
                send_key $cmd{ok};
                next;
            }

            die "Unknown popup message" unless check_screen('autoyast-known-warning', 0);

            # Wait until popup disappears
            die "Popup message without timeout" unless wait_screen_change { sleep 11 };
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
        }
        elsif (match_has_tag('inst-betawarning')) {
            send_key $cmd{ok};
            push(@needles, 'autoyast-license') if (get_var('AUTOYAST_LICENSE'));
            next;
        }
        elsif (match_has_tag('autoyast-postpartscript')) {
            @needles = grep { $_ ne 'autoyast-postpartscript' } @needles;
            $postpartscript = 1;
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
            die "autoyast_license";
        }
    }

    # CaaSP does not have second stage
    return if is_caasp;

    mouse_hide(1);
    $maxtime = 1000;
    $timer   = 0;
    $stage   = 'stage2';

    check_screen \@needles, $check_time;
    until (match_has_tag 'reboot-after-installation') {
        #Verify timeout and continue if there was a match
        next unless verify_timeout_and_check_screen(($timer += $check_time), [qw(reboot-after-installation autoyast-postinstall-error)]);
        if (match_has_tag('autoyast-postinstall-error')) {
            $self->handle_expected_errors(iteration => $i);
            $num_errors++;
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
    $self->save_and_upload_yastlogs;
}

1;

# vim: set sw=4 et:
