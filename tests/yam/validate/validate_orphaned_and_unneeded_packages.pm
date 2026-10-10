# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check orphaned and unneded packages on Agama installed system
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;

sub run {
    select_console 'root-console';

    my $build = get_var('BUILD');
    my $arch = get_var('ARCH');
    my $orphaned_file = "${build}_${arch}_orphaned_packages.txt";
    my $unneeded_file = "${build}_${arch}_unneeded_packages.txt";
    my $orphaned_output = script_output("zypper packages --orphaned 2>&1 | tee /tmp/${orphaned_file}");
    my $unneeded_output = script_output("zypper packages --unneeded 2>&1 | tee /tmp/${unneeded_file}");

    if ($orphaned_output !~ qr/No packages found./) {
        record_soft_failure('bsc#1284152 - Detected orphaned packages on installed system');
        upload_logs("/tmp/${orphaned_file}");
    }

    if ($unneeded_output !~ qr/No packages found./) {
        record_soft_failure('bsc#1284152 - Detected unneded packages on installed system');
        upload_logs("/tmp/${unneeded_file}");
    }
}

1;
