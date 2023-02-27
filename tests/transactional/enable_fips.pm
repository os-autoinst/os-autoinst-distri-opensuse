# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: FIPS
# Summary: Enable FIPS on transactional server
#
# Maintainer: QA-C team <qa-c@suse.de>

use Mojo::Base "consoletest";
use testapi;
use transactional;
use bootloader_setup qw(change_grub_config);
use version_utils qw(is_sle_micro);

sub run {
    select_console 'root-console';

    # make sure fips is not enabled
    assert_script_run("grep '^0\$' /proc/sys/crypto/fips_enabled");

    # install fips pattern
    my $pkg = is_sle_micro ? 'microos-fips' : 'fips';
    record_info('INFO', "Installing pattern: $pkg");
    trup_call("pkg install -t pattern $pkg");
    change_grub_config('=\"[^\"]*', '& fips=1 ', 'GRUB_CMDLINE_LINUX_DEFAULT');
    trup_call('--continue grub.cfg');
    check_reboot_changes;

    record_info('kernel cmdline', script_output('cat /proc/cmdline'));
    assert_script_run("grep '^1\$' /proc/sys/crypto/fips_enabled");
    record_info('INFO', 'FIPS enabled');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
