# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
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

our @EXPORT = qw(upload_system_logs);

# Save the output of $cmd into $file and upload it
sub system_status {
    my ($self, $log) = @_;
    $log //= "/tmp/system-status.log";

    my %cmds = (
        kernel                     => "uname -a",
        cpuinfo                    => "cat /proc/cpuinfo",
        memory                     => "free -m",
        repos                      => "zypper repos -u",
        lspci                      => "lspci",
        lsmod                      => "lsmod",
        vmstat                     => "vmstat -w",
        w                          => "w",
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
    $log //= "/tmp/journalctl.log";
    script_run("journalctl -b -o short-precise >$log", 40);
    return $log;
}

sub dmesg_log {
    my ($self, $log) = @_;
    $log //= "/tmp/dmesg.log";
    script_run("dmesg >$log", 40);
    return $log;
}

sub upload_system_logs {
    upload_logs(system_status(),  timeout => 100, failok => 1);
    upload_logs(journalctl_log(), timeout => 100, failok => 1);
    upload_logs(dmesg_log(),      timeout => 100, failok => 1);
}

1;
