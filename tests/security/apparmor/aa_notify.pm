# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
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
# Maintainer: QE Security <none@suse.de>
# Tags: poo#36883, tc#1621139

use strict;
use warnings;
use base "apparmortest";
use testapi;
use utils;
use version_utils qw(is_sle);

use constant ENABLED => 1;
use constant DISABLED => 0;


sub nscd_service_autorestart {
    my $enable = shift;
    if ($enable) {
        assert_script_run 'rm /etc/systemd/system/nscd.service.d/override.conf';
        assert_script_run 'rmdir /etc/systemd/system/nscd.service.d/';
    } else {
        assert_script_run 'mkdir -p /etc/systemd/system/nscd.service.d';
        assert_script_run 'echo -e "[Service]\nRestart=no" > /etc/systemd/system/nscd.service.d/override.conf';
    }
    assert_script_run 'systemctl daemon-reload';
}


sub run {
    my ($self) = @_;

    my $tmp_prof = "/tmp/apparmor.d";
    my $audit_log = "/var/log/audit/audit.log";
    my $executable_name = "/usr/sbin/nscd";

    zypper_call('in nscd');

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

    nscd_service_autorestart(DISABLED);

    systemctl('restart nscd', expect_false => 1);
    upload_logs($audit_log);

    validate_script_output "aa-notify -l -v", sub {
        m/
            Name:\s+\/etc\/nscd\.conf.*
            Denied:\s+r.*
            AppArmor\sdenials?:\s+[0-9]+\s+\(since/sxx
    };

    # Make sure it could restore to the default profile
    assert_script_run "aa-disable -d $tmp_prof nscd";

    # restore enforce mode
    validate_script_output "aa-enforce $executable_name", sub {
        m/Setting.*nscd to enforce mode/;
    }, timeout => 180;

    systemctl("restart nscd");
    $self->aa_tmp_prof_clean("$tmp_prof");
    nscd_service_autorestart(ENABLED);
}

1;
