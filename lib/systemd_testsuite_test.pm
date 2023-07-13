# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: library functions for setting up the tests and uploading logs in error case.
# Maintainer: Thomas Blume <tblume@suse.com>


package systemd_testsuite_test;
use base "opensusebasetest";

use strict;
use warnings;
use known_bugs;
use testapi;
use Utils::Backends;
use Utils::Architectures;
use power_action_utils 'power_action';
use utils 'zypper_call';
use version_utils qw(is_opensuse is_sle is_tumbleweed);
use bootloader_setup qw(change_grub_config grub_mkconfig);
use Utils::Logging qw(save_and_upload_log tar_and_upload_log);

sub testsuiteinstall {
    my ($self) = @_;
    # The isotovideo setting QA_TESTSUITE_REPO is not mandatory.
    # QA_TESTSUITE_REPO is meant to override the default repos with a custom OBS repo to test changes on the test suite package.
    my $qa_testsuite_repo = get_var('QA_TESTSUITE_REPO', '');
    if (!$qa_testsuite_repo) {
        if (is_opensuse()) {
            my $sub_project;
            if (is_tumbleweed()) {
                $sub_project = 'Tumbleweed/openSUSE_Tumbleweed/';
            }
            else {
                (my $version, my $service_pack) = split('\.', get_required_var('VERSION'));
                $sub_project = "Leap:/$version/openSUSE_Leap_$version.$service_pack/";
            }
            $qa_testsuite_repo = 'https://download.opensuse.org/repositories/devel:/openSUSE:/QA:/' . $sub_project;
        }
        else {
            my $version_with_service_pack = get_required_var('VERSION');
            $qa_testsuite_repo = "http://download.suse.de/ibs/QA:/Head/SLE-$version_with_service_pack/";
        }
        die '$qa_testsuite_repo is not set' unless ($qa_testsuite_repo);
    }

    select_console 'root-console';

    if (is_sle('15+') && !main_common::is_updates_tests) {
        # add devel tools repo for SLE15 to install strace
        my $devel_repo = get_required_var('REPO_SLE_MODULE_DEVELOPMENT_TOOLS');
        zypper_call "ar -c $utils::OPENQA_FTP_URL/" . $devel_repo . " devel-repo";
    }

    zypper_call 'in strace';

    # install systemd testsuite
    zypper_call "ar $qa_testsuite_repo systemd-testrepo";
    zypper_call '--gpg-auto-import-keys ref';
    # use systemd from the repo of the qa package
    if (get_var('SYSTEMD_FROM_TESTREPO')) {
        if (is_sle('>15-SP2')) { zypper_call 'rm systemd-bash-completion' }
        zypper_call 'in --from systemd-testrepo systemd systemd-sysvinit udev libsystemd0 systemd-coredump libudev1';
        change_grub_config('=.*', '=9', 'GRUB_TIMEOUT');
        grub_mkconfig;
        wait_screen_change { enter_cmd "shutdown -r now" };
        if (is_s390x) {
            $self->wait_boot(bootloader_time => 180);
        } else {
            $self->handle_uefi_boot_disk_workaround if (is_aarch64);
            wait_still_screen 10;
            send_key 'ret';
            wait_serial('Welcome to', 300) || die "System did not boot in 300 seconds.";
        }
        assert_screen('linux-login', 30);
        reset_consoles;
        select_console('root-console');
    }
    zypper_call 'in systemd-qa-testsuite';
}

sub testsuiteprepare {
    my ($self, $testname, $option) = @_;
    #cleanup and prepare next test
    assert_script_run "find / -maxdepth 1 -type f -print0 | xargs -0 /bin/rm -f";
    assert_script_run 'find /etc/systemd/system/ -name "schedule.conf" -prune -o \( \! -name *~ -type f -print0 \) | xargs -0 /bin/rm -f';
    assert_script_run "find /etc/systemd/system/ -name 'end.service' -delete";
    assert_script_run "rm -rf /var/tmp/systemd-test*";
    assert_script_run "clear";
    assert_script_run "cd /usr/lib/systemd/tests";
    assert_script_run "./run-tests.sh $testname --setup 2>&1 | tee /tmp/testsuite.log", 300;

    if ($option eq 'nspawn') {
        my $testservicepath = script_output "sed -n '/testservice=/s/root/nspawn-root/p' logs/$testname-setup.log";
        assert_script_run "ls -l \$\{testservicepath#testservice=\}";
    }
    else {
        #tests and versions that don't need a reboot
        return if ($testname eq 'TEST-18-FAILUREACTION' || $testname eq 'TEST-21-SYSUSERS' || is_sle('>15-SP2') || is_tumbleweed);

        assert_script_run 'ls -l /etc/systemd/system/testsuite.service';
        #virtual machines do a vm reset instead of reboot
        if (!is_qemu || ($option eq 'needreboot')) {
            wait_screen_change { enter_cmd "shutdown -r now" };
            if (is_s390x) {
                $self->wait_boot(bootloader_time => 180);
            }
            else {
                $self->handle_uefi_boot_disk_workaround if (is_aarch64);
                wait_serial('Welcome to', 300) || die "System did not boot in 300 seconds.";
            }
            wait_still_screen 10;
            assert_screen('linux-login', 30);
            reset_consoles;
            select_console('root-console');
        }
    }

    script_run "clear";
}

sub post_fail_hook {
    my ($self) = @_;
    #upload logs from given testname
    tar_and_upload_log('/usr/lib/systemd/tests/logs', '/tmp/systemd_testsuite-logs.tar.bz2');
    tar_and_upload_log('/var/log/journal /run/log/journal', 'binary-journal-log.tar.bz2');
    save_and_upload_log('journalctl --no-pager -axb -o short-precise', 'journal.txt');
    upload_logs('/shutdown-log.txt', failok => 1);
}


1;
