# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check orphaned and unneded packages on Agama installed system
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use File::Path 'make_path';
use File::Copy 'copy';

sub run {
    select_console 'root-console';

    my $build = get_var('BUILD');
    my $arch = get_var('ARCH');
    my $test = get_var('TEST');
    my $tar_name = "${build}_${arch}_${test}.tar.gz";
    my $orphaned_output = script_output('zypper -q packages --orphaned', proceed_on_failure => 1);
    my $unneeded_output = script_output('zypper -q packages --unneeded', proceed_on_failure => 1);
    my $orphaned_file = "B${build}_${arch}_${test}_orphaned_packages.txt";
    my $unneeded_file = "B${build}_${arch}_${test}_unneeded_packages.txt";
    $orphaned_file = length($orphaned_file) > 80 ? "orphaned_packages.txt" : $orphaned_file;
    $unneeded_file = length($unneeded_file) > 80 ? "unneeded_packages.txt" : $unneeded_file;

    make_path('ulogs');
    if ($orphaned_output !~ qr/No packages found./) {
        record_soft_failure('Detected orphaned packages on installed system');
        save_tmp_file($orphaned_file, $orphaned_output);
        copy(hashed_string($orphaned_file), 'ulogs/' . $orphaned_file);
    }

    if ($unneeded_output !~ qr/No packages found./) {
        record_soft_failure('Detected unneded packages on installed system');
        save_tmp_file($unneeded_file, $unneeded_output);
        copy(hashed_string($unneeded_file), 'ulogs/' . $unneeded_file);
    }
}

1;
