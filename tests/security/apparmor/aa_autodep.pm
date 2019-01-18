# Copyright (C) 2018 SUSE LLC
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
#
# Summary: Guess basic AppArmor profile requirements with aa_autodep
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36889, tc#1621141

use base 'apparmortest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;

    my $aa_tmp_prof = "/tmp/apparmor.d";
    my $scan_ans    = [
        {
            word => qr/Inactive local profile/m,
            key  => 'c',
        },
        {
            word => qr/AUTODEP-DONE/m,
            end  => 1,
        },
    ];

    $self->aa_disable_stdout_buf("/usr/sbin/aa-autodep");
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

    $self->aa_interactive_run("aa-autodep -d $aa_tmp_prof /usr/bin/pam* ; echo AUTODEP-DONE", $scan_ans, 300);

    # Output generated profiles list to serial console
    assert_script_run "ls -1 $aa_tmp_prof/*pam* > tee /dev/$serialdev";

    assert_script_run "aa-disable -d $aa_tmp_prof usr.sbin.nscd";
    $self->aa_tmp_prof_clean("$aa_tmp_prof");
}

1;
