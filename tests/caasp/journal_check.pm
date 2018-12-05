# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic CaaSP journal tests
# Maintainer: Tomas Hehejik <thehejik@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use caasp;

sub run {
    my $bug_pattern = {
        bsc_1062349         => '.*vbd.*xenbus_dev_probe on device.*',
        bsc_1022527_FEATURE => '.*wickedd.*ni_process_reap.*blocking waitpid.*',
        bsc_1022524_FEATURE => '.*rpc\.statd.*Failed to open directory sm.*',
        bsc_1022525_FEATURE => '.*rpcbind.*cannot(.*open file.*rpcbind.xdr.*|.*open file.*portmap.xdr.*|.*save any registration.*)',
        bsc_1023818         => '.*Dev dev-disk-by.*device appeared twice with different sysfs paths.*',
        bsc_1033792         => '.*blk_update_request.*error.*dev fd0.*sector 0.*',
        bsc_1047923         => '.*e820: (cannot find a gap in the 32bit address range|PCI devices with unassigned 32bit BARs may break!)',
        bsc_1058703         => '.*Specified group \'.*\' unknown.*',
        bsc_1025217_FEATURE => '.*piix4_smbus.*SMBus (Host Controller not enabled|base address uninitialized - upgrade BIOS).*',
        bsc_1025218_FEATURE => '.*dmi.*Firmware registration failed.*',
        bsc_1028060_FEATURE => '.*getting etcd lock took too long, reboot canceld.*',
        bsc_1071224         => '.*Failed to start Mask tmp.mount by default on SUSE systems.*',
        poo_31951_FEATURE   => '.*Spectre V2 \:.*LFENCE not serializing.*',
        bsc_1118321         => '.*update-checker-migration.timer.*(Failed to parse calendar specification|Timer unit lacks value setting).*',
    };
    my $master_pattern = "(" . join('|', map { "$_" } values %$bug_pattern) . ")";

    my $journal_output = script_output("journalctl --no-pager -p err -b 0 | tail -n +2");

    # Find lines which matches to the pattern_bug
    while (my ($bug, $pattern) = each %$bug_pattern) {
        my $buffer = "";
        my $result = "";
        foreach my $line (split(/\n/, $journal_output)) {
            $buffer .= $line . "\n" if ($line =~ /$pattern/);
        }
        if ($buffer) {
            $result = $bug =~ 'FEATURE' ? 'ok' : 'softfail';
            record_info $bug, $buffer, result => $result;
        }
    }

    # Find lines which doesn't match to the pattern_bug by using master_pattern
    foreach my $line (split(/\n/, $journal_output)) {
        record_info('Unknown issue', $line, result => 'fail') if ($line !~ /$master_pattern/);
    }

    # Write full journal output for reference and upload it into Uploaded Logs section in test webUI
    script_run("journalctl --no-pager -b 0 > /tmp/full_journal.log");
    upload_logs "/tmp/full_journal.log";

    # Check for failed systemd services and examine them
    # script_run("pkill -SEGV dbus-daemon"); # comment out for a test
    my $failed_services = script_output("systemctl --failed --no-legend --plain --no-pager");
    foreach my $line (split(/\n/, $failed_services)) {
        if ($line =~ /^([\w.-]+)\s.+$/) {
            my $failed_service_output = script_output("systemctl status $1 -l || true");
            record_info "$1 failed", $failed_service_output, result => 'fail';
        }
    }
}

1;
