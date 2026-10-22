# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check orphaned packages on Agama installed system
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;

sub run {
    select_console 'root-console';

    my $test_name = substr(get_var('TEST'), 0, 40);
    my $file = get_var('BUILD') . "_" . get_var('ARCH') . "_" . $test_name . "_orphaned_packages.txt";
    if (script_run("zypper packages --orphaned > /tmp/${file} 2>&1") == 0) {
        my $output = script_output("cat /tmp/${file}");
        if ($output !~ qr/No packages found\./) {
            record_soft_failure("bsc#1284152 - Detected orphaned packages on installed system");
            upload_logs("/tmp/${file}");
        }
        record_info('Zypper output', $output);
    }
}

1;
