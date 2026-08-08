# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: tcpdump
# Summary: test tcpdump by pinging a localhost and dumping with an icmp filter
# Maintainer: QE Core <qe-core@suse.com>

use Mojo::Base 'consoletest';
use testapi;
use utils;
use package_utils 'install_package';
use serial_terminal 'select_serial_terminal';

sub run {
    my ($self) = @_;
    my $tcpdump_log_file = "/tmp/tcpdump.log";
    my $pid_file = '/tmp/tcpdump.pid';

    select_serial_terminal;

    install_package("tcpdump", trup_reboot => 1);
    # Start tcpdump in the background sniffing ICMP on loopback
    script_run("tcpdump -i lo icmp -vv > $tcpdump_log_file 2>&1 & echo \$! > $pid_file");
    # Wait until tcpdump is ready before sending traffic
    script_retry("grep -q 'listening on' $tcpdump_log_file", delay => 1, retry => 10);
    sleep 2;
    assert_script_run("ping -c10 -i0.2 localhost -4");

    assert_script_run("kill \$(cat $pid_file)");
    # Wait for tcpdump to exit and flush its summary
    script_retry("! kill -0 \$(cat $pid_file) 2>/dev/null", delay => 1, retry => 5);
    record_info("TEST LOG", script_output("cat $tcpdump_log_file"));
    validate_script_output("cat $tcpdump_log_file", sub { m/0 packets dropped by kernel/ });
}
1;
