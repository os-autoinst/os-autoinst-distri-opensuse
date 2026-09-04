# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Verify the system is booted with systemd-boot
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use utils;

sub run {

    select_console 'root-console';

    my $output = script_output('bootctl status');

    die "Validation failed: Current Boot Loader Product is not 'systemd-boot'!\n"
      unless $output =~ /Current Boot Loader:[\s\S]*?Product:\s+systemd-boot/;
}

sub post_fail_hook {
    script_run('efibootmgr -v > /tmp/efibootmgr.log');
    script_run('bootctl status > /tmp/bootctl_status.log');
    upload_logs('/tmp/efibootmgr.log');
    upload_logs('/tmp/bootctl_status.log');
    shift->SUPER::post_fail_hook();
}

sub test_flags {
    return {fatal => 1};
}

1;
