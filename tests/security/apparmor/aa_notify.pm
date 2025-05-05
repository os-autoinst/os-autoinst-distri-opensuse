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
    my $audit_service = is_tumbleweed ? 'audit-rules' : 'auditd';
    my $test_bin = is_sle('<=15-sp4') ? 'nscd' : 'smbd';
    my $test_service = is_sle('<=15-sp4') ? 'nscd' : 'smb';
    my $executable_name = "/usr/sbin/$test_bin";

    systemctl("restart $audit_service");

    $self->aa_tmp_prof_prepare("$tmp_prof");

    #Add root user to the use_group
    assert_script_run "sed -i s/admin/root/ /etc/apparmor/notify.conf";

    assert_script_run "echo > $audit_log";

    validate_script_output "aa-notify -l", sub { m/^(AppArmor\sdenials:\s+0\s+\(since.*)?$/ };

    # Make it failed intentionally to get some audit messages
    assert_script_run "sed -i '/\\/etc\\/nscd.conf/d' $tmp_prof/usr.sbin.nscd" if is_sle('<=15-sp4');
    assert_script_run "sed -i '/samba/d' $tmp_prof/usr.sbin.smbd" unless is_sle('<=15-sp4');
    assert_script_run "cat $tmp_prof/usr.sbin.$test_bin";

    assert_script_run "aa-disable $test_bin";
    assert_script_run "aa-enforce -d $tmp_prof $test_bin";

    nscd_service_autorestart(DISABLED) if is_sle('<=15-sp4');
    smbd_service_autorestart(DISABLED) unless is_sle('<=15-sp4');

    systemctl("restart $test_service", expect_false => 1);
    upload_logs($audit_log);

    validate_script_output "aa-notify -l -v", sub {
        m/
            Name:\s+\/etc\/nscd\.conf.*
            Denied:\s+r.*
            AppArmor\sdenials?:\s+[0-9]+\s+\(since/sxx
    } if is_sle('<=15-sp4');

    validate_script_output "aa-notify -l -v", sub {
        m/
            Name:.*samba.*
            Denied:\s+ac.*
            AppArmor\sdenials?:\s+[0-9]+\s+\(since/sxx
    } unless is_sle('<=15-sp4');

    # Make sure it could restore to the default profile
    assert_script_run "aa-disable -d $tmp_prof $test_bin";

    # restore enforce mode
    validate_script_output "aa-enforce $executable_name", sub {
        m/Setting.*$test_bin to enforce mode/;
    }, timeout => 180;

    systemctl("restart $test_service");
    $self->aa_tmp_prof_clean("$tmp_prof");
    nscd_service_autorestart(ENABLED) if is_sle('<=15-sp4');
    smbd_service_autorestart(ENABLED) unless is_sle('<=15-sp4');
}

1;
