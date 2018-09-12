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
# Summary: Test the utility for updating AppArmor security profiles
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36892, tc#1621143

use base "apparmortest";
use strict;
use testapi;
use utils;

sub run {
    my ($self) = @_;

    my $output;
    my $aa_tmp_prof = "/tmp/apparmor.d";

    my $aa_logprof_allow = qr/\(A\)llow/m;
    my $aa_logprof_save  = qr/\(S\)ave Changes/m;

    my $scan_ans = [
        {
            word => qr/\(A\)llow/m,
            key  => 'a',
        },
        {
            word => qr/\(S\)ave Changes/m,
            key  => 's',
            end  => 1,
        },
    ];

    systemctl('stop nscd');
    systemctl('restart auditd');

    $self->aa_disable_stdout_buf("/usr/sbin/aa-logprof");
    $self->aa_tmp_prof_prepare("$aa_tmp_prof", 1);

    my @aa_logprof_items = ('capability setuid', '\/var\/log\/nscd.log');

    # Remove some rules from profile
    foreach my $item (@aa_logprof_items) {
        assert_script_run "sed -i '/$item/d' $aa_tmp_prof/usr.sbin.nscd";
    }

    validate_script_output "aa-complain -d $aa_tmp_prof usr.sbin.nscd", sub { m/Setting.*complain/ };

    systemctl('start nscd');

    $self->aa_interactive_run("aa-logprof -d $aa_tmp_prof", $scan_ans);

    validate_script_output "cat $aa_tmp_prof/usr.sbin.nscd", sub {
        m/
            include\s+<tunables\/global>.*
            \/usr\/sbin\/nscd\s+flags=\(complain\)\s*\{.*
            \/etc\/nscd\.conf\s+r.*
            \/usr\/sbin\/nscd\s+mrix.*
            \}/sxx
    };

    $self->aa_tmp_prof_verify("$aa_tmp_prof", 'nscd');
    $self->aa_tmp_prof_clean("$aa_tmp_prof");
}

1;
