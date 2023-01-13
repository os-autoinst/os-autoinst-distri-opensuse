# Copyright 2015-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Autoyast installation
# - Create a list with expected installation steps
# - Iterate the list and check results against the steps
#   - Handle pxe and network boot
#   - Handle nonexisting package messages
#   - Handle autoyast warning pop-ups
#   - Handle scc and linuxrc errors
#   - Handle licence and beta warnings
#   - Handle certificate warnings
#   - Handle package failures
#   - Handle installation overview
#   - Handle nvidia repositories
#   - Confirm installation
# - After installation is finished and system reboots
#   - Handle pxe and network boot
#   - Handle unreachable repositories
#   - Handle warning pop ups
#   - Handle autoyast errors during second stage
#   - Handle grub to boot on local disk (aarch64)
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use Utils::Architectures;
use utils;
use power_action_utils 'prepare_system_shutdown';
use version_utils qw(is_sle is_microos is_released is_upgrade);
use main_common 'opensuse_welcome_applicable';
use x11utils 'untick_welcome_on_next_startup';
use Utils::Backends;
use scheduler 'get_test_suite_data';
use autoyast 'test_ayp_url';
use y2_logs_helper qw(upload_autoyast_profile upload_autoyast_schema);
use validate_encrypt_utils "validate_encrypted_volume_activation";

my $confirmed_licenses = 0;
my $stage = 'stage1';
my $maxtime = 2000 * get_var('TIMEOUT_SCALE', 1);    #Max waiting time for stage 1
my $check_time = 50;    #Period to check screen during stage 1 and 2

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

    test_ayp_url;
    my $test_data = get_test_suite_data();
    my @needles = qw(bios-boot nonexisting-package reboot-after-installation linuxrc-install-fail scc-invalid-url warning-pop-up autoyast-boot package-notification nvidia-validation-failed import-untrusted-gpg-key);

    my $expected_licenses = get_var('AUTOYAST_LICENSE');
    my @expected_warnings;
    if (defined $test_data->{expected_warnings}) {
        @expected_warnings = @{$test_data->{expected_warnings}};
        push(@needles, @expected_warnings);
    }
    my @processed_warnings;
    if (get_var('EXTRABOOTPARAMS') =~ m/startshell=1/) {
        push @needles, 'linuxrc-start-shell-after-installation';
    }
    push @needles, 'autoyast-confirm' if get_var('AUTOYAST_CONFIRM');
    push @needles, 'autoyast-postpartscript' if get_var('USRSCR_DIALOG');
    # Do not try to fail early in case of autoyast_error_dialog scenario
    # where we test that certain error are properly handled
    push @needles, 'autoyast-error' unless get_var('AUTOYAST_EXPECT_ERRORS');
    # Autoyast reboot automatically without confirmation, usually assert 'bios-boot' that is not existing on zVM
    # So push a needle to check upcoming reboot on zVM that is a way to indicate the stage done
    push @needles, 'autoyast-stage1-reboot-upcoming' if is_s390x || (is_pvm && !is_upgrade);
    # Similar situation over IPMI backend, we can check against PXE menu
    push @needles, qw(prague-pxe-menu qa-net-selection) if is_ipmi;
    # Import untrusted certification for SMT
    push @needles, 'untrusted-ca-cert' if get_var('SMT_URL');
    # Workaround for removing package error during upgrade
    push(@needles, 'ERROR-removing-package') if get_var("AUTOUPGRADE");
    # resolve conflicts and this is a workaround during the update
    push(@needles, 'manual-intervention') if get_var("BREAK_DEPS", '1');
    # match openSUSE Welcome dialog on matching distros
    push(@needles, 'opensuse-welcome') if opensuse_welcome_applicable;
    push(@needles, 'salt-formula-motd-setup') if get_var("SALT_FORMULAS_PATH");
    # If it's beta, we may match license screen before pop-up shows, so check for pop-up first
    if (get_var('BETA')) {
        push(@needles, 'inst-betawarning');
    }
    elsif ($expected_licenses) {
        push(@needles, 'autoyast-license');
    }

    if (is_sle('=15')) {
        record_info('bsc#1179654', 'Needs at least libzypp-17.4.0 to avoid validation check failed');
        push @needles, 'expired-gpg-key';
    }

    # Push needle 'inst-bootmenu' to ensure boot from hard disk on aarch64
    push(@needles, 'inst-bootmenu') if (is_aarch64 && get_var('UPGRADE'));
    # If we have an encrypted root or boot volume, we reboot to a grub password prompt.
    push(@needles, 'encrypted-disk-password-prompt') if get_var("ENCRYPT_ACTIVATE_EXISTING");
    # Kill ssh proactively before reboot to avoid half-open issue on zVM, do not need this on zKVM
    prepare_system_shutdown if is_backend_s390x;
    my $postpartscript = 0;
    my $confirmed = 0;
    my $pxe_boot_done = 0;

    my $i = 1;
    my $num_errors = 0;
    my $timer = 0;    # Prevent endless loop

    check_screen \@needles, $check_time;
    until (match_has_tag('reboot-after-installation')
          || match_has_tag('opensuse-welcome')
          || match_has_tag('bios-boot')
          || match_has_tag('autoyast-stage1-reboot-upcoming')
          || match_has_tag('inst-bootmenu')
          || match_has_tag('lang_and_keyboard')
          || match_has_tag('encrypted-disk-password-prompt'))
    {
        #Verify timeout and continue if there was a match
        next unless verify_timeout_and_check_screen(($timer += $check_time), \@needles);
        if (match_has_tag('autoyast-boot')) {
            send_key 'ret';    # press enter if grub timeout is disabled, like we have in reinstall scenarios
            last;    # if see grub, we get to the second stage, as it appears after bios-boot which we may miss
        }
        elsif (match_has_tag('import-untrusted-gpg-key')) {
            handle_untrusted_gpg_key;
            @needles = grep { $_ ne 'import-untrusted-gpg-key' } @needles;
            next;
        }
        elsif (match_has_tag('prague-pxe-menu') || match_has_tag('qa-net-selection')) {
            @needles = grep { $_ ne 'prague-pxe-menu' and $_ ne 'qa-net-selection' } @needles;
            $pxe_boot_done = 1;
            send_key 'ret';    # boot from harddisk
            next;    # first stage is over, now we should see grub with autoyast-boot
        }
        #repeat until timeout or login screen
        elsif (match_has_tag('nonexisting-package')) {
            @needles = grep { $_ ne 'nonexisting-package' } @needles;
            $self->handle_expected_errors(iteration => $i);
            $num_errors++;
        }
        elsif (match_has_tag('warning-pop-up')) {
            # in order to avoid to match several times the same already processed warning
            next if scalar grep { match_has_tag($_) } @processed_warnings;

            # Softfail only on sle
            if (is_sle && check_screen('warning-partition-reduced', 0)) {
                # See poo#19978, no timeout on partition warning, hence need to click OK button to soft-fail
                record_info('bsc#1045470',
                    "There is no timeout on sle for reduced partition screen by default.\n"
                      . "See bsc#1045470 for details.");
                send_key_until_needlematch 'create-partition-plans-finished', $cmd{ok};
                next;
            }
            @processed_warnings = grep { match_has_tag($_) } @expected_warnings;
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
            if (get_var('ENCRYPT_ACTIVATE_EXISTING')) {
                validate_encrypted_volume_activation({
                        mapped_device => $test_data->{mapped_device},
                        device_status => $test_data->{device_status}->{message},
                        properties => $test_data->{device_status}->{properties}
                });
            }

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
        elsif (match_has_tag('manual-intervention')) {
            $self->deal_with_dependency_issues;
            assert_screen 'installation-settings-overview-loaded';
            send_key 'alt-u';
            wait_screen_change { send_key 'alt-u' };
            next;
        }
        elsif (match_has_tag('salt-formula-motd-setup')) {
            @needles = grep { $_ ne 'salt-formula-motd-setup' } @needles;
            # used for salt-formulas
            send_key 'alt-m';
            type_string "$test_data->{motd_text}";
            assert_screen 'salt-formulas-motd-changed';
            send_key $cmd{next};
            assert_screen 'salt-formulas-running-provisioner';
            next;
        }
        elsif (match_has_tag('autoyast-postpartscript')) {
            @needles = grep { $_ ne 'autoyast-postpartscript' } @needles;
            $postpartscript = 1;
        }
        elsif (match_has_tag('autoyast-error')) {
            die 'Error detected during first stage of the installation';
        }
        elsif (match_has_tag('nvidia-validation-failed')) {
            # nvidia repositories are unstable and really not needed for anything
            record_info("NVIDIA", "NVIDIA repository is broken");
            wait_still_screen { send_key 'alt-o' };
            send_key 'alt-n';
            $num_errors++;
        }
        elsif (match_has_tag('package-notification')) {
            send_key 'alt-o';
        }
        elsif (match_has_tag('linuxrc-start-shell-after-installation')) {
            @needles = grep { $_ ne 'linuxrc-start-shell-after-installation' } @needles;
            enter_cmd "exit";
        }
        elsif (match_has_tag 'expired-gpg-key') {
            send_key 'alt-y';
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

    # Cannot verify second stage properly on s390x, so reconnect to already installed system
    if (is_s390x) {
        reconnect_mgmt_console(timeout => 700, grub_timeout => 180);
        return;
    }
    # For powerVM need to switch to mgmt console to handle the reboot properly
    if (is_pvm()) {
        prepare_system_shutdown;
        reconnect_mgmt_console(timeout => 500);
    }

    # If we didn't see pxe, the reboot is going now
    $self->wait_boot if is_ipmi and not get_var('VIRT_AUTOTEST') and not $pxe_boot_done;

    # Second stage starts here
    $maxtime = 1000 * get_var('TIMEOUT_SCALE', 1);    # Max waiting time for stage 2
    $timer = 0;
    $stage = 'stage2';

    check_screen \@needles, $check_time;
    @needles = qw(reboot-after-installation autoyast-postinstall-error autoyast-boot unreachable-repo warning-pop-up inst-bootmenu lang_and_keyboard encrypted-disk-password-prompt);
    # Do not try to fail early in case of autoyast_error_dialog scenario
    # where we test that certain error are properly handled
    push @needles, 'autoyast-error' unless get_var('AUTOYAST_EXPECT_ERRORS');
    # match openSUSE Welcome dialog on matching distros
    push(@needles, 'opensuse-welcome') if opensuse_welcome_applicable;
    # There will be another reboot for IPMI backend
    push @needles, qw(prague-pxe-menu qa-net-selection) if is_ipmi;
    until (match_has_tag('reboot-after-installation')
          || match_has_tag('opensuse-welcome'))
    {
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
            # Finish the current module execution if encrypted disks are used.
            # Delegate entering the encryption passphrase and boot validation to the
            # next test modules.
            return if (get_var('ENCRYPT'));
        }
        elsif (match_has_tag('prague-pxe-menu') || match_has_tag('qa-net-selection')) {
            last;    # we missed reboot-after-installation, wait for boot is in autoyast/console
        }
        elsif (match_has_tag('unreachable-repo')) {
            # skip nvidia repo, this repo is problematic and not needed
            send_key 'alt-s';
        }
        elsif (match_has_tag('warning-pop-up')) {
            handle_warnings;    # Process warnings during stage 2
        }
        elsif (match_has_tag('autoyast-error')) {
            die 'Error detected during second stage of the installation';
        }
        elsif (match_has_tag('inst-bootmenu')) {
            $self->wait_grub_to_boot_on_local_disk;
        }
        elsif (match_has_tag('lang_and_keyboard')) {
            return;
        }
        elsif (match_has_tag('encrypted-disk-password-prompt')) {
            return;
        }
    }
    # ssh console was activated at this point of time, so need to reset
    reset_consoles if is_pvm;
    my $expect_errors = get_var('AUTOYAST_EXPECT_ERRORS') // 0;
    die 'exceeded expected autoyast errors' if $num_errors != $expect_errors;
    if (scalar @expected_warnings != scalar @processed_warnings) {
        die "Test Fail! Expected warnings did not appear during the installation." .
          "Expected: @expected_warnings Processed: @processed_warnings";
    }

}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    $self->upload_autoyast_profile;
    $self->upload_autoyast_schema;
}

1;
