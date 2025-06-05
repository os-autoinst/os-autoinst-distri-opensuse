# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Collect all logs needed for containers
# Maintainer: qa-c@suse.de

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;
use strict;
use warnings;

sub run {
    select_serial_terminal;

    my $log_dir = "/tmp/logs/";
    assert_script_run "mkdir -p $log_dir";
    assert_script_run "cd $log_dir";

    script_run('df -h > df-h.txt');
    script_run('dmesg > dmesg.txt');
    script_run('findmnt > findmnt.txt');
    script_run('rpm -qa | sort > rpm-qa.txt');
    script_run('sysctl -a > sysctl.txt');
    script_run('systemctl > systemctl.txt');
    script_run('systemctl status > systemctl-status.txt');
    script_run('systemctl list-unit-files > systemctl_units.txt');
    script_run('journalctl -b > journalctl-b.txt', timeout => 120);
    script_run('tar zcf containers-conf.tgz $(find /etc/containers /usr/share/containers -type f)');

    for my $ip_version (4, 6) {
        script_run("ip -$ip_version addr > ip$ip_version-addr.txt");
        script_run("ip -$ip_version route > ip$ip_version-route.txt");
    }
    script_run("iptables-save > iptables.txt");
    script_run("ip6tables-save > ip6tables.txt");
    script_run('nft list ruleset > nft.txt');

    # Remove all empty logs
    script_run "find $log_dir -type f -size 0 -exec rm -f {} +";

    my @logs = split /\s+/, script_output "ls";
    for my $log (@logs) {
        upload_logs($log_dir . $log);
    }

    upload_logs('/proc/config.gz');
    upload_logs('/var/log/audit/audit.log', log_name => "audit.txt");
}

1;
