# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: apparmor-utils
# Summary: Single testcase for AppArmor that guesses basic profile requirements
# for nscd and pam using aa_autodep.
# - Create a temporary profile for nscd in "/tmp/apparmor.d" using
# "aa-autodep -d $aa_tmp_prof/ nscd"
# - Check if "/tmp/apparmor.d/usr.sbin.nscd" contains required fields
# - Create a temporaty profile for /usr/bin/pam*
# - Output created pam profile to serial output
# - Disable temporarily created nscd profile
# - Cleanup temporary profiles
# Maintainer: QE Security <none@suse.de>
# Tags: poo#36889, poo#45803, poo#106002

use base 'apparmortest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;

    my $aa_tmp_prof = "/tmp/apparmor.d";
    my $test_binfiles = "/usr/bin/pam*";

    $self->aa_tmp_prof_prepare($aa_tmp_prof, 0);

    assert_script_run "aa-autodep -d $aa_tmp_prof/ nscd";

    validate_script_output "cat $aa_tmp_prof/usr.sbin.nscd", sub {
        m/
            include\s+<tunables\/global>.*
            \/usr\/sbin\/nscd\s+flags=\(complain\)\s*\{.*
            include\s+<abstractions\/base>.*
            \/usr\/sbin\/nscd\s+mr.*
            \}/sxx
    };

    # Check the test files exist, double check to avoid performance issue
    my $ret = script_run "ls -1 $test_binfiles > tee /dev/$serialdev";
    if ($ret) {
        # If failed try sync and then check again
        assert_script_run "sync";
        assert_script_run "ls -1 $test_binfiles > tee /dev/$serialdev";
    }

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

    # Output generated profiles list to serial console
    # Check the new generated test files exist, double check to avoid performance issue
    $ret = script_run "ls -1 $aa_tmp_prof/*pam* > tee /dev/$serialdev";
    if ($ret) {
        # If failed then try sync and then check again
        assert_script_run "sync";
        assert_script_run "ls -1 $aa_tmp_prof/*pam* > tee /dev/$serialdev";
    }

    assert_script_run "aa-disable -d $aa_tmp_prof usr.sbin.nscd";
    $self->aa_tmp_prof_clean("$aa_tmp_prof");
}

1;
