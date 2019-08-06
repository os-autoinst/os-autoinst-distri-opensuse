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
# Summary: Test the utility for updating AppArmor security profiles.
# - Stops nscd and restarts auditd
# - Create a temporary profile dir on /tmp
# - Remove '/usr.*nscd mrix' and 'nscd\.conf' from /tmp/apparmor.d/usr.sbin.nscd
# - Run "aa-complain -d /tmp/apparmor.d usr.sbin.nscd" check for "setting
# complain"
# - Start nscd, upload logfiles
# - Run "aa-logprof -d /tmp/apparmor.d" interactivelly
# - Check /tmp/apparmor.d/usr.sbin.nscd" for '/usr.*nscd mrix' and 'nscd\.conf'
# - Check if nscd could start with the temporary apparmor profiles
# - Cleanup temporary directory
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36892, poo#45803

use base "apparmortest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_tumbleweed';

sub run {
    my ($self) = @_;
    my $log_file = $apparmortest::audit_log;
    my $output;
    my $aa_tmp_prof = "/tmp/apparmor.d";

    systemctl('stop nscd');
    systemctl('restart auditd');

    $self->aa_tmp_prof_prepare("$aa_tmp_prof", 1);

    my @aa_logprof_items = ('\/usr.*\/nscd mrix', 'nscd\.conf r');

    # Remove some rules from profile
    foreach my $item (@aa_logprof_items) {
        assert_script_run "sed -i '/$item/d' $aa_tmp_prof/usr.sbin.nscd";
    }

    validate_script_output "aa-complain -d $aa_tmp_prof usr.sbin.nscd", sub { m/Setting.*complain/ };

    # For tumbleweed, unload /usr/sbin/nscd profile in case, clean up the audit.log
    if (is_tumbleweed) {
        script_run "echo '/usr/sbin/nscd {}' | apparmor_parser -R";
    }
    assert_script_run "echo > $log_file";

    systemctl('start nscd');

    # Upload audit.log for reference
    upload_logs "$log_file";

    script_run_interactive(
        "aa-logprof -d $aa_tmp_prof",
        [
            {
                prompt => qr/\(A\)llow/m,
                key    => 'a',
            },
            {
                prompt => qr/\(S\)ave Changes/m,
                key    => 's',
            },
        ],
        30
    );

    foreach my $item (@aa_logprof_items) {
        validate_script_output "cat $aa_tmp_prof/usr.sbin.nscd", sub { m/$item/ };
    }

    $self->aa_tmp_prof_verify("$aa_tmp_prof", 'nscd');
    $self->aa_tmp_prof_clean("$aa_tmp_prof");
}

1;
