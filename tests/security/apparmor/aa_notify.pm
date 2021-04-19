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
# Package: audit nscd apparmor-utils
# Summary: Display information about logged AppArmor messages
# - Restart auditd
# - Create temporary apparmor profile on /tmp
# - Add root to use_group on /etc/apparmor/notify.conf
# - Run "aa-notify -l"
# - Make nscd fail intentionally, removing "/etc/nscd.conf" entry from
# /tmp/apparmor.d/usr.sbin.nscd
# - Run "aa-disable nscd"
# - Put nscd back in enforce mode: "aa-enforce -d /tmp/apparmor.d nscd"
# - Restart nscd
# - Check the errors from "aa-notify -l -v"
# - Disable temporary profile, put nscd back in enforce mode, restart nscd
# - Cleanup temporary profiles
# Maintainer: llzhao <llzhao@suse.com>
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

    validate_script_output "aa-notify -l", sub { m/^(AppArmor\sdenials:\s+0\s+\(since.*)?$/ };

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
