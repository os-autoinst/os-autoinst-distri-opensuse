# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic CASP journal tests
# Maintainer: Tomas Hehejik <thehejik@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub write_detail_output {
    my ($self, $title, $output, $result) = @_;

    $result =~ /^(ok|fail|softfail)$/ || die "Result value: $result not allowed.";

    my $filename = $self->next_resultname('txt');
    my $detail   = {
        title  => $title,
        result => $result,
        text   => $filename,
    };
    push @{$self->{details}}, $detail;

    open my $fh, '>', bmwqemu::result_dir() . "/$filename";
    print $fh $output;
    close $fh;

    # Set overall result for the job
    if ($result eq 'fail') {
        $self->{result} = $result;
    }
    elsif ($result eq 'ok') {
        $self->{result} ||= $result;
    }
}

sub run() {
    my ($self) = @_;

    my $bug_pattern = {
        bsc_1022527 => '.*wickedd.*ni_process_reap.*blocking waitpid.*',
        bsc_1022524 => '.*rpc\.statd.*Failed to open directory sm.*',
        bsc_1022525 => '.*rpcbind.*cannot(.*open file.*rpcbind.xdr.*|.*open file.*portmap.xdr.*|.*save any registration.*)',
        bsc_1023818 => '.*Dev dev-disk-by.*device appeared twice with different sysfs paths.*',
        bsc_1025217 => '.*piix4_smbus.*SMBus Host Controller not enabled.*',
        bsc_1025218 => '.*dmi.*Firmware registration failed.*',
    };
    my $master_pattern = "(" . join('|', map { "$_" } values %$bug_pattern) . ")";

    my $journal_output = script_output("journalctl --no-pager -p err -b 0 | tail -n +2\n");

    # Find lines which matches to the pattern_bug
    while (my ($bug, $pattern) = each %$bug_pattern) {
        my $buffer = "";
        foreach my $line (split(/\n/, $journal_output)) {
            $buffer .= $line . "\n" if ($line =~ /$pattern/);
        }
        $self->write_detail_output($bug, $buffer, "softfail") if $buffer;
    }

    # Find lines which doesn't match to the pattern_bug by using master_pattern
    foreach my $line (split(/\n/, $journal_output)) {
        $self->write_detail_output("Unknown issue", $line, "fail") if ($line !~ /$master_pattern/);
    }

    # Write full journal output for reference and upload it into Uploaded Logs section in test webUI
    script_run("journalctl --no-pager -b 0 > /tmp/full_journal.log");
    upload_logs "/tmp/full_journal.log";

    # Check for failed systemd services and examine them
    # script_run("pkill -SEGV dbus-daemon"); # comment out for a test
    my $failed_services = script_output("systemctl --failed --no-legend --plain --no-pager\n");
    foreach my $line (split(/\n/, $failed_services)) {
        if ($line =~ /^([\w.-]+)\s.+$/) {
            my $failed_service_output = script_output("systemctl status $1 -l || true\n");
            $self->write_detail_output("$1 failed", $failed_service_output, "fail");
        }
    }
}

sub test_flags() {
    return {important => 1};
}

1;
