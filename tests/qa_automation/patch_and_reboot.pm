# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
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
use qam;
use Utils::Backends 'use_ssh_serial_console';
use power_action_utils qw(power_action);
use version_utils qw(is_sle);
use serial_terminal qw(add_serial_console);
use version_utils qw(is_jeos);

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    quit_packagekit unless check_var('DESKTOP', 'textmode');

    zypper_call(q{mr -d $(zypper lr | awk -F '|' '{IGNORECASE=1} /nvidia/ {print $2}')}, exitcode => [0, 3]);

    add_test_repositories;

    # JeOS is a bootable image and doesn't have installation where we can install
    #   updates as for SLE DVD installation, so we need to update manually.
    if (is_jeos) {
        record_info('Updates', script_output('zypper lu'));
        zypper_call('up', timeout => 300);
    } else {
        fully_patch_system;
    }

    my $suffix = is_jeos ? '-base' : '';
    assert_script_run("rpm -ql --changelog kernel-default$suffix > /tmp/kernel_changelog.log");
    upload_logs('/tmp/kernel_changelog.log');

    # DESKTOP can be gnome, but patch is happening in shell, thus always force reboot in shell
    power_action('reboot', textmode => 1);
    $self->wait_boot(bootloader_time => 150);
}

sub test_flags {
    return {fatal => 1};
}

1;
