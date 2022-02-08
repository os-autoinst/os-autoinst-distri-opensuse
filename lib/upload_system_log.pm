# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
package upload_system_log;
# Summary:  base class for collecting and uploading system log
# Maintainer: Yong Sun <yosun@suse.com>

use strict;
use warnings;
use base "Exporter";
use Exporter;
use testapi;
use utils;
use base "opensusebasetest";
use Utils::Architectures;

our @EXPORT = qw(upload_system_logs upload_supportconfig_log);

# Save the output of $cmd into $file and upload it
sub system_status {
    my ($self, $log) = @_;
    $log //= "/tmp/system-status.txt";

    my %cmds = (
        kernel => "uname -a",
        cpuinfo => "cat /proc/cpuinfo",
        memory => "free -m",
        repos => "zypper repos -u",
        lspci => "lspci",
        lsmod => "lsmod",
        vmstat => "vmstat -w",
        w => "w",
        '/proc/sys/kernel/tainted' => "cat /proc/sys/kernel/tainted",
    );

    foreach my $key (keys %cmds) {
        my $cmd = "echo '=========> $key <=========' >> $log; ";
        $cmd .= "$cmds{$key} >> $log; ";
        $cmd .= "echo '' >> $log";
        script_run($cmd, 40);
    }
    return $log;
}

sub journalctl_log {
    my ($self, $log) = @_;
    $log //= "/tmp/journalctl.txt";
    script_run("journalctl -b -o short-precise >$log", 40);
    return $log;
}

sub dmesg_log {
    my ($self, $log) = @_;
    $log //= "/tmp/dmesg.txt";
    script_run("dmesg >$log", 40);
    return $log;
}

sub upload_system_logs {
    upload_logs(system_status(), timeout => 100, failok => 1);
    upload_logs(journalctl_log(), timeout => 100, failok => 1);
    upload_logs(dmesg_log(), timeout => 100, failok => 1);
}

sub upload_supportconfig_log {
    my (%args) = @_;
    if (is_s390x) {
        $args{file_name} //= "supportconfig";
    } else {
        $args{file_name} //= 'supportconfig.' . script_output("date '+%Y%m%d%H%M%S'");
    }
    $args{options} //= '';
    $args{timeout} //= 600;

    my $file_name = $args{file_name};
    assert_script_run("supportconfig -B $file_name", $args{timeout});
    my $scc_tarball = "/var/log/scc_$file_name.txz";
    my $nts_tarball = "/var/log/nts_$file_name.txz";

    # bcc#1166774
    if (script_run("test -e $scc_tarball") == 0) {
        upload_logs($scc_tarball);
    } elsif (script_run("test -e $nts_tarball") == 0) {
        upload_logs("$nts_tarball");
    } else {
        assert_script_run("ls /var/log");
        die("No supportconfig directory found!");
    }
}

1;
