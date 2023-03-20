# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#

# inherit qa_run, but overwrite run
# Summary: QA Automation: patch the system before running the test
#          This is to test Test Updates
# - Stop packagekit service (unless DESKTOP is textmode)
# - Disable nvidia repository
# - Add test repositories from system variables (PATCH_TEST_REPO,
# MAINT_TEST_REPO)
# - Install system patches
# - Upload kernel changelog
# - Reboot system and wait for bootloader
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use utils;
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Architectures;
use qam;
use Utils::Backends qw(use_ssh_serial_console is_pvm);
use power_action_utils qw(power_action);
use version_utils qw(is_sle);
use serial_terminal qw(add_serial_console);
use version_utils qw(is_jeos);

sub run {
    my $self = shift;
    select_serial_terminal;

    quit_packagekit unless check_var('DESKTOP', 'textmode');

    zypper_call(q{mr -d $(zypper lr | awk -F '|' '{IGNORECASE=1} /nvidia/ {print $2}')}, exitcode => [0, 3]);

    add_test_repositories;

    # JeOS is a bootable image and doesn't have installation where we can install
    #   updates as for SLE DVD installation, so we need to update manually.
    if (is_jeos) {
        record_info('Updates', script_output('zypper lu'));
        zypper_call('up', timeout => 600);
        if (is_aarch64) {
            # Disable grub timeout for aarch64 cases so that the test doesn't stall
            assert_script_run("sed -ie \'s/GRUB_TIMEOUT.*/GRUB_TIMEOUT=-1/\' /etc/default/grub");
            assert_script_run('grub2-mkconfig -o /boot/grub2/grub.cfg');
            record_info('GRUB', script_output('cat /etc/default/grub'));
        }
    } else {
        fully_patch_system;
    }

    my $suffix = is_jeos ? '-base' : '';
    assert_script_run("rpm -ql --changelog kernel-default$suffix > /tmp/kernel_changelog.log");
    zypper_call("lr -u", log => 'repos_list.txt');
    upload_logs('/tmp/kernel_changelog.log');
    upload_logs('/tmp/repos_list.txt');

    # DESKTOP can be gnome, but patch is happening in shell, thus always force reboot in shell
    power_action('reboot', textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(ready_time => 600, bootloader_time => get_var('BOOTLOADER_TIMEOUT', 300));
}

sub test_flags {
    return {fatal => 1};
}

1;
