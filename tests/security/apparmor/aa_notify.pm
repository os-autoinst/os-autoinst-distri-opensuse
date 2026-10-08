# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: audit smbd apparmor-utils
# Summary: Display information about logged AppArmor messages
# - Restart auditd
# - Create temporary apparmor profile on /tmp
# - Add root to use_group on /etc/apparmor/notify.conf
# - Run "aa-notify -s 1"
# - Make smbd fail intentionally, removing "/etc/smbd.conf" entry from
# /tmp/apparmor.d/usr.sbin.smbd
# - Run "aa-disable smbd"
# - Put smbd back in enforce mode: "aa-enforce -d /tmp/apparmor.d smbd"
# - Restart smbd
# - Check the errors from "aa-notify -s 1 -v"
# - Disable temporary profile, put smbd back in enforce mode, restart smbd
# - Cleanup temporary profiles
# Maintainer: QE Security <none@suse.de>
# Tags: poo#36883, tc#1621139, poo#201084

use Mojo::Base 'apparmortest';
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

    # Use "-s 1" (since-days) instead of "-l" (last login) as "-l" depends on
    # having a login recorded in lastlog2.db/wtmp, which is not guaranteed to
    # exist on freshly installed images (poo#201084). Also match the expected
    # line with "/m" instead of anchoring the whole output, as newer
    # apparmor-notify versions can print additional informational lines
    # (e.g. "ttkthemes not found. Install for best user experience.")
    # before the actual denial summary.
    if (is_sle('<=12-sp5')) {
        # apparmor-utils 2.8.2 (SLE 12-SP5) prints no output at all when
        # there are no denials (poo#204807).
        validate_script_output "aa-notify -s 1", sub { !/\S/ };
    } else {
        validate_script_output "aa-notify -s 1", sub { m/^AppArmor\sdenials?:\s+0\s+\(since.*$/m };
    }

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

    validate_script_output "aa-notify -s 1 -v", sub {
        m/
            Name:\s+\/etc\/nscd\.conf.*
            Denied:\s+r.*
            AppArmor\sdenials?:\s+[0-9]+\s+\(since/sxx
    } if is_sle('<=15-sp4');

    validate_script_output "aa-notify -s 1 -v", sub {
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
