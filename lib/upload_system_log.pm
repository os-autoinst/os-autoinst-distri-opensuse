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
    my ($self, $log, $timeout) = @_;
    $log //= "/tmp/system-status.txt";
    $timeout //= 40;

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
        script_run($cmd, $timeout);
    }
    return $log;
}

sub journalctl_log {
    my ($self, $log, $timeout) = @_;
    $log //= "/tmp/journalctl.txt";
    script_run("journalctl -b -o short-precise >$log", $timeout // 40);
    return $log;
}

sub dmesg_log {
    my ($self, $log, $timeout) = @_;
    $log //= "/tmp/dmesg.txt";
    script_run("dmesg >$log", $timeout // 40);
    return $log;
}

# Optional: timeout => <s> for the commands (default 40),
# upload_timeout => <s> for the uploads (default 100)
sub upload_system_logs {
    my (%args) = @_;
    my $timeout = $args{timeout} // 40;
    my $upload_timeout = $args{upload_timeout} // 100;
    upload_logs(system_status(undef, undef, $timeout), timeout => $upload_timeout, failok => 1);
    upload_logs(journalctl_log(undef, undef, $timeout), timeout => $upload_timeout, failok => 1);
    upload_logs(dmesg_log(undef, undef, $timeout), timeout => $upload_timeout, failok => 1);
}

sub upload_supportconfig_log {
    my (%args) = @_;
    $args{file_name} //= 'supportconfig.' . script_output("date '+%Y%m%d%H%M%S'");
    $args{options} //= '';
    $args{timeout} //= 600;

    my $file_name = $args{file_name};
    assert_script_run("supportconfig -B $file_name", $args{timeout});
    my $scc_tarball_tbz = "/var/log/scc_$file_name.tbz";
    my $scc_tarball_txz = "/var/log/scc_$file_name.txz";
    my $nts_tarball_tbz = "/var/log/nts_$file_name.tbz";
    my $nts_tarball_txz = "/var/log/nts_$file_name.txz";

    # bcc#1166774
    if (script_run("test -e $scc_tarball_tbz") == 0) {
        upload_logs($scc_tarball_tbz);
    } elsif (script_run("test -e $scc_tarball_txz") == 0) {
        upload_logs($scc_tarball_txz);
    } elsif (script_run("test -e $nts_tarball_tbz") == 0) {
        upload_logs("$nts_tarball_tbz");
    } elsif (script_run("test -e $nts_tarball_txz") == 0) {
        upload_logs("$nts_tarball_txz");
    } else {
        assert_script_run("ls /var/log");
        die("No supportconfig directory found!");
    }
}

1;
