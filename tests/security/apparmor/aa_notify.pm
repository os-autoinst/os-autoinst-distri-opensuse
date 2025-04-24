# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: audit smbd apparmor-utils
# Summary: Display information about logged AppArmor messages
# - Restart auditd
# - Create temporary apparmor profile on /tmp
# - Add root to use_group on /etc/apparmor/notify.conf
# - Run "aa-notify -l"
# - Make smbd fail intentionally, removing "/etc/smbd.conf" entry from
# /tmp/apparmor.d/usr.sbin.smbd
# - Run "aa-disable smbd"
# - Put smbd back in enforce mode: "aa-enforce -d /tmp/apparmor.d smbd"
# - Restart smbd
# - Check the errors from "aa-notify -l -v"
# - Disable temporary profile, put smbd back in enforce mode, restart smbd
# - Cleanup temporary profiles
# Maintainer: QE Security <none@suse.de>
# Tags: poo#36883, tc#1621139

use strict;
use warnings;
use base "apparmortest";
use testapi;
use utils;
use version_utils qw(is_sle is_tumbleweed);

use constant ENABLED => 1;
use constant DISABLED => 0;


sub smbd_service_autorestart {
    my $enable = shift;
    if ($enable) {
        assert_script_run 'rm /etc/systemd/system/smbd.service.d/override.conf';
        assert_script_run 'rmdir /etc/systemd/system/smbd.service.d/';
    } else {
        assert_script_run 'mkdir -p /etc/systemd/system/smbd.service.d';
        assert_script_run 'echo -e "[Service]\nRestart=no" > /etc/systemd/system/smbd.service.d/override.conf';
    }
    assert_script_run 'systemctl daemon-reload';
}


sub run {
    my ($self) = @_;

    my $tmp_prof = "/tmp/apparmor.d";
    my $audit_log = "/var/log/audit/audit.log";
    my $executable_name = "/usr/sbin/smbd";
    my $audit_service = is_tumbleweed ? 'audit-rules' : 'auditd';

    systemctl("restart $audit_service");

    $self->aa_tmp_prof_prepare("$tmp_prof");

    #Add root user to the use_group
    assert_script_run "sed -i s/admin/root/ /etc/apparmor/notify.conf";

    assert_script_run "echo > $audit_log";

    validate_script_output "aa-notify -l", sub { m/^(AppArmor\sdenials:\s+0\s+\(since.*)?$/ };

    # Make it failed intentionally to get some audit messages
    assert_script_run "sed -i '/samba/d' $tmp_prof/usr.sbin.smbd";
    assert_script_run "cat $tmp_prof/usr.sbin.smbd";

    assert_script_run "aa-disable smbd";
    assert_script_run "aa-enforce -d $tmp_prof smbd";

    smbd_service_autorestart(DISABLED);

    systemctl('restart smb', expect_false => 1);
    upload_logs($audit_log);

    validate_script_output "aa-notify -l -v", sub {
        m/
            Name:.*samba.*
            Denied:\s+ac.*
            AppArmor\sdenials?:\s+[0-9]+\s+\(since/sxx
    };

    # Make sure it could restore to the default profile
    assert_script_run "aa-disable -d $tmp_prof smbd";

    # restore enforce mode
    validate_script_output "aa-enforce $executable_name", sub {
        m/Setting.*smbd to enforce mode/;
    }, timeout => 180;

    systemctl("restart smb");
    $self->aa_tmp_prof_clean("$tmp_prof");
    smbd_service_autorestart(ENABLED);
}

1;
