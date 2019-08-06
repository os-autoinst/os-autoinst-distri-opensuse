# Copyright (C) 2018-2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Single testcase for AppArmor that guesses basic profile requirements
# for nscd and pam using aa_autodep.
# - Create a temporary profile for nscd in "/tmp/apparmor.d" using
# "aa-autodep -d $aa_tmp_prof/ nscd"
# - Check if "/tmp/apparmor.d/usr.sbin.nscd" contains required fields
# - Create a temporaty profile for /usr/bin/pam*
# - Output created pam profile to serial output
# - Disable temporarily created nscd profile
# - Cleanup temporary profiles
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36889, poo#45803

use base 'apparmortest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;

    my $aa_tmp_prof = "/tmp/apparmor.d";

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

    script_run_interactive(
        "aa-autodep -d $aa_tmp_prof /usr/bin/pam*",
        [
            {
                prompt => qr/Inactive local profile/m,
                key    => 'c',
            },
        ],
        30
    );

    # Output generated profiles list to serial console
    assert_script_run "ls -1 $aa_tmp_prof/*pam* > tee /dev/$serialdev";

    assert_script_run "aa-disable -d $aa_tmp_prof usr.sbin.nscd";
    $self->aa_tmp_prof_clean("$aa_tmp_prof");
}

1;
