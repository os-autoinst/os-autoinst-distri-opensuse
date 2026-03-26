# Copyright 2015-2024 LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: zypper patch for maintenance
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';
use version_utils 'is_leap';

sub get_patch_id {
    my $patch_id;
    if (is_leap('>=16')) {
        $patch_id = script_output("zypper -n lp -a | grep " . get_var('INCIDENT_PATCH') . " | awk '{print \$3}' | uniq");
    } else {
        $patch_id = get_var('INCIDENT_PATCH');
    }

    return $patch_id;
}

sub run {
    select_serial_terminal;

    if (script_run("test -s \$XDG_RUNTIME_DIR/install_packages.txt") != 0) {
        record_info('The packages to be released are new ones', 'We need to install them via zypper');
        # Only one package per line in the file
        my @packages = split(/ /, get_var("INSTALL_PACKAGES"));
        foreach my $item (@packages) {
            script_run("echo $item >> \$XDG_RUNTIME_DIR/install_packages.txt");
        }
        assert_script_run("xargs --no-run-if-empty zypper -n in -l --force-resolution --solver-focus Update < \$XDG_RUNTIME_DIR/install_packages.txt", 1400);

    } else {

        my $patch_id = get_patch_id;
        my $patch_info = script_output("zypper -n info -t patch $patch_id", 200);
        record_info "$patch_id", "$patch_info";

        if ($patch_info =~ /^Status.*:.*applied/m) {
            record_info("Failed to patch", "Patch is marked as applied", result => fail);
            die "Patch is marked as applied, please check that submission is correct";
        }

        # NVIDIA repo needs new signing key, see poo#163094
        my $sign_key = get_var('BUILD') =~ /openSUSE-repos/ ? '--gpg-auto-import-keys' : '';
        zypper_call("$sign_key in -l -t patch " . $patch_id, exitcode => [0, 102, 103], timeout => 1400);
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
