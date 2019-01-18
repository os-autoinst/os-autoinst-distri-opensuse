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
#
# Summary: Test the profile generation utility of Apparmor
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36886, tc#1621140

use strict;
use warnings;
use base "apparmortest";
use testapi;
use utils;

sub run {
    my ($self) = @_;

    my $aa_tmp_prof           = "/tmp/apparmor.d";
    my $aa_genprof_filter_pre = [
        {
            word => qr/\(S\)can system.*\(F\)inish/m,
            key  => 's',
            end  => 1,
        },
    ];
    my $aa_genprof_filter = [
        {
            word => qr/\(A\)llow.*\(D\)eny/m,
            key  => 'a',
        },
        {
            word => qr/\(S\)ave Changes/m,
            key  => 's',
        },
        {
            word => qr/\(S\)can system.*\(F\)inish/m,
            key  => 'f',
            end  => 1,
        },
    ];

    systemctl('start auditd');

    $self->aa_disable_stdout_buf("/usr/sbin/aa-genprof");
    $self->aa_tmp_prof_prepare("$aa_tmp_prof");

    assert_script_run("rm -f  $aa_tmp_prof/usr.sbin.nscd");

    # Run the command in background so that we could run other commands
    script_run("(aa-genprof -d $aa_tmp_prof nscd|tee /dev/$serialdev) &", 0);
    sleep 5;
    send_key 'ret';    # Back to the shell prompt

    systemctl('restart nscd');

    # Call the job to the front ground
    script_run("fg", 0);
    send_key 'ret';    # Work around for Tumblweed

    $self->aa_interactive_run(undef, $aa_genprof_filter_pre);
    $self->aa_interactive_run(undef, $aa_genprof_filter);

    # Not all rules will be checked here, only the critical ones.
    validate_script_output "cat $aa_tmp_prof/usr.sbin.nscd", sub {
        m/
		    include\s+<tunables\/global>.*
            \/usr\/sbin\/nscd\s*{.*
            include\s+<abstractions\/base>.*
            \/usr\/sbin\/nscd\s+mr.*
            }/sxx
    };

    $self->aa_tmp_prof_verify("$aa_tmp_prof", 'nscd');
    $self->aa_tmp_prof_clean("$aa_tmp_prof");
}

1;
