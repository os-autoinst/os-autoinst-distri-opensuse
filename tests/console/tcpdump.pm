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
use version_utils qw(is_sle);

sub run {
    my ($self) = @_;
    my $tcpdump_log_file = "/tmp/tcpdump.log";
    my $pid_file = '/tmp/tcpdump.pid';

    select_serial_terminal;

    install_package("tcpdump", trup_reboot => 1);
    # Start tcpdump in the background sniffing ICMP on loopback
    script_run("tcpdump -i lo icmp and src localhost -vv > $tcpdump_log_file 2>&1 & echo \$! > $pid_file");
    # Wait until tcpdump is ready before sending traffic
    script_retry("grep -q 'listening on' $tcpdump_log_file", delay => 1, retry => 10);
    my $ipv4_option = is_sle('=12-sp3') ? '' : ' -4';
    assert_script_run("ping -c4$ipv4_option localhost");

    assert_script_run("kill \$(cat $pid_file)");
    # Wait for tcpdump to exit and flush its summary
    script_retry("! kill -0 \$(cat $pid_file) 2>/dev/null", delay => 1, retry => 5);
    record_info("TEST LOG", script_output("cat $tcpdump_log_file"));
    validate_script_output("cat $tcpdump_log_file", sub { m/0 packets dropped by kernel/ });
}
sub test_flags {
    return {fatal => 0, no_rollback => 1};
}

1;
