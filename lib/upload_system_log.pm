# SUSE's openQA tests
#
#Copyright © 2017 SUSE LLC
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

    my @klst = ("kernel", "cpuinfo", "memory", "repos", "lspci");
    my %cmds = (
        kernel  => "uname -a",
        cpuinfo => "cat /proc/cpuinfo",
        memory  => "free -m",
        repos   => "zypper repos -u",
        lspci   => "lspci",
    );

    foreach my $key (@klst) {
        my $cmd = "echo '=========> $key <=========' >> $log; ";
        $cmd .= "$cmds{$key} >> $log; ";
        $cmd .= "echo '' >> $log";
        script_run($cmd, 40);
    }
    return $log;
}

sub journalctl_log {
    my ($self, $sys_log) = @_;
    $sys_log //= "/tmp/journalctl.log";
    script_run("journalctl -b >$sys_log", 40);

    return $sys_log;
}

sub upload_system_logs {
    my $log     = system_status();
    my $sys_log = journalctl_log();

    upload_logs($log,     timeout => 100);
    upload_logs($sys_log, timeout => 100);
}

1;
