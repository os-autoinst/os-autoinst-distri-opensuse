# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: tcpdump
# Summary: test tcpdump by pinging a localhost and dumping with an icmp filter
# Maintainer: QE Core <qe-core@suse.com>

use base "consoletest";
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';

sub run {
    my ($self) = @_;
    my $tcpdump_log_file = "/tmp/tcpdump.log";
    my $pid_file = '/tmp/tcpdump.pid';

    select_serial_terminal;

    zypper_call "in tcpdump";
    # Start tcpdump to sniff only icmp loclhost packets in background and do ping
    script_run("tcpdump -i lo icmp and src localhost -vv > $tcpdump_log_file 2>&1 & echo \$! > $pid_file & sleep 4");
    assert_script_run("ping -c4 localhost -4 & sleep 4");

    assert_script_run("kill \$(cat $pid_file)");
    record_info("TEST LOG", script_output("cat $tcpdump_log_file"));
    validate_script_output("cat $tcpdump_log_file", sub { m/0 packets dropped by kernel/ });
}
1;
