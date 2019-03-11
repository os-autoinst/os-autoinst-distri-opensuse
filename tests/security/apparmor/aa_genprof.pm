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
# Tags: poo#36886, poo#45803

use strict;
use warnings;
use base "apparmortest";
use testapi;
use utils;

sub run {
    my ($self) = @_;

    my $aa_tmp_prof = "/tmp/apparmor.d";
    my $sc_dtch_msg = "Screen detached";
    my $sc_term_msg = "Screen terminated";

    systemctl('start auditd');

    $self->aa_tmp_prof_prepare("$aa_tmp_prof");

    assert_script_run("rm -f  $aa_tmp_prof/usr.sbin.nscd");

    # Run aa-genprof command in screen so that we could restart nscd at the
    # same time while it is waiting for scan
    script_run("screen -m ; echo '$sc_dtch_msg' > /dev/$serialdev", 0);

    # Confirm it is in the screen
    validate_script_output "echo \$TERM", sub { m/screen/ };

    script_run("script -c 'aa-genprof -d $aa_tmp_prof nscd' /dev/null |& tee /dev/$serialdev", 0);
    wait_serial("Please start the application", 20);

    # Detach screen
    send_key 'ctrl-a';
    sleep 1;
    send_key 'd';
    wait_serial("$sc_dtch_msg", 10);    # confirm detached

    systemctl('restart nscd');
    sleep 3;

    # reattach screen
    script_run("screen -r ; echo '$sc_term_msg' > /dev/$serialdev", 0);
    send_key 's';

    script_run_interactive(
        undef,
        [
            {
                prompt => qr/\(A\)llow.*\(D\)eny/m,
                key    => 'a',
            },
            {
                prompt => qr/\(S\)ave Changes/m,
                key    => 's',
            },
            {
                prompt => qr/\(S\)can system.*\(F\)inish/m,
                key    => 'f',
            },
        ],
        30
    );

    # Exit screen
    send_key 'ctrl-d';
    wait_serial("$sc_term_msg", 10);    # confirm terminated

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
