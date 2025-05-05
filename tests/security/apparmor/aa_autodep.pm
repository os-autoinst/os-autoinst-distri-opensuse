# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: apparmor-utils
# Summary: Single testcase for AppArmor that guesses basic profile requirements
# for smbd and pam using aa_autodep.
# - Create a temporary profile for smbd in "/tmp/apparmor.d" using
# "aa-autodep -d $aa_tmp_prof/ smbd"
# - Check if "/tmp/apparmor.d/usr.sbin.smbd" contains required fields
# - Create a temporaty profile for /usr/bin/pam*
# - Output created pam profile to serial output
# - Disable temporarily created smbd profile
# - Cleanup temporary profiles
# Maintainer: QE Security <none@suse.de>
# Tags: poo#36889, poo#45803, poo#106002

use base 'apparmortest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_opensuse);
use serial_terminal qw(select_serial_terminal);

sub run {
    my ($self) = @_;

    my $aa_tmp_prof = "/tmp/apparmor.d";
    my $test_binfiles = "/usr/bin/pam*";
    my $test_pkg = is_sle('<=15-sp4') ? 'nscd' : 'samba';
    my $test_bin = is_sle('<=15-sp4') ? 'nscd' : 'smbd';

    $self->aa_tmp_prof_prepare($aa_tmp_prof, 0);

    assert_script_run "aa-autodep -d $aa_tmp_prof/ $test_bin";

    validate_script_output "cat $aa_tmp_prof/usr.sbin.$test_bin", sub {
        m/
            include\s+<tunables\/global>.*
            \/usr\/sbin\/$test_bin\s+flags=\(complain\)\s*\{.*
            include\s+<abstractions\/base>.*
            \/usr\/sbin\/$test_bin\s+mr.*
            \}/sxx
    };

    # Check the test files exist, double check to avoid perfomance issue
    my $ret = script_run "ls -1 $test_binfiles | tee /dev/$serialdev";
    if ($ret) {
        # If failed try sync and then check again
        assert_script_run "sync";
        assert_script_run "ls -1 $test_binfiles | tee /dev/$serialdev";
    }

    select_console 'root-console';
    script_run_interactive(
        "aa-autodep -d $aa_tmp_prof /usr/bin/pam*",
        [
            {
                prompt => qr/Inactive local profile/m,
                key => 'c',
            },
        ],
        90
    );
    select_serial_terminal;

    # Output generated profiles list to serial console
    # Check the new genrated test files exist, double check to avoid perfomance issue
    $ret = script_run "ls -1 $aa_tmp_prof/*pam* | tee /dev/$serialdev";
    if ($ret) {
        # If failed then try sync and then check again
        assert_script_run "sync";
        assert_script_run "ls -1 $aa_tmp_prof/*pam* | tee /dev/$serialdev";
    }

    assert_script_run "aa-disable -d $aa_tmp_prof usr.sbin.$test_bin";
    $self->aa_tmp_prof_clean("$aa_tmp_prof");

    assert_script_run "aa-status | tee /dev/$serialdev";

    # delete cache file of aa-autodep generated profile, so that the next reload creates a fresh cache of /etc/apparmor.d/usr.sbin.smbd
    # (wouldn't happen without deleting the cache file because the cache timestamp is newer than the profile (+ used abstractions) timestamp)
    my $target_dir = (is_sle('>=15-SP2') || is_opensuse) ? '/var/cache/apparmor/' : '/var/lib/apparmor/cache/';
    assert_script_run "find $target_dir -name usr.sbin.$test_bin -delete";
}

1;
