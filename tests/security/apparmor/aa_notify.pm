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
# Summary: Display information about logged AppArmor messages. The test starts
# by creating a temporary profile for nscd. Then adds root to user group. To
# validate, removes /etc/nscd.conf from temporary profile directory, restarts
# nscd with temporary security profile and checks the aa-notify output looking
# for missing /etc/nscd.conf entry.
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36883, tc#1621139

use strict;
use warnings;
use base "apparmortest";
use testapi;
use utils;

sub run {
    my ($self) = @_;

    my $tmp_prof  = "/tmp/apparmor.d";
    my $audit_log = "/var/log/audit/audit.log";

    systemctl('restart auditd');

    $self->aa_tmp_prof_prepare("$tmp_prof");

    #Add root user to the use_group
    assert_script_run "sed -i s/admin/root/ /etc/apparmor/notify.conf";

    assert_script_run "echo > $audit_log";

    validate_script_output "aa-notify -l", sub { m/^$/ };

    # Make it failed intentionally to get some audit messages
    assert_script_run "sed -i '/\\/etc\\/nscd.conf/d' $tmp_prof/usr.sbin.nscd";

    assert_script_run "aa-disable nscd";
    assert_script_run "aa-enforce -d $tmp_prof nscd";

    systemctl('restart nscd', expect_false => 1);
    upload_logs($audit_log);

    validate_script_output "aa-notify -l -v", sub {
        m/
            Name:\s+\/etc\/nscd\.conf.*
            Denied:\s+r.*
            AppArmor\sdenials:\s+[0-9]+\s+\(since/sxx
    };

    # Make sure it could restore to the default profile
    assert_script_run "aa-disable -d $tmp_prof nscd";
    assert_script_run "aa-enforce nscd";
    systemctl("restart nscd");

    $self->aa_tmp_prof_clean("$tmp_prof");
}

1;
