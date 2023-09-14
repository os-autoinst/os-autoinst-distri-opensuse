# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: transactional-update
# Summary: Disable SELinux on transactional server
#
# Maintainer: QA-C team <qa-c@suse.de>

use base "consoletest";
use testapi;
use strict;
use warnings;
use transactional qw(process_reboot);
use bootloader_setup qw(replace_grub_cmdline_settings);
use selinuxtest qw(check_disabled);

sub run {
    select_console 'root-console';

    assert_script_run "sed -i -e 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config";
    # DEPRECATED runtime disable
    # see https://github.com/SELinuxProject/selinux-kernel/wiki/DEPRECATE-runtime-disable
    replace_grub_cmdline_settings('selinux=1', 'selinux=0', update_grub => 1);
    process_reboot(trigger => 1);
    check_disabled;

}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
