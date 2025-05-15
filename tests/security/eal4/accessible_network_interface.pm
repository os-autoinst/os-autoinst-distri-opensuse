# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'Accessible network interface' test case of EAL4 test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#111899

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use eal4_test;
use Data::Dumper;

sub run {
    my ($self) = shift;
    my $test_log = "accessible_network_interface_log.txt";

    select_console 'root-console';

    # The result of 'lsof -i -P' likes:
    #   COMMAND    PID     USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
    #   wickedd-d  890     root    8u  IPv4  16913      0t0  UDP *:68
    # So we put the expected listen ports to a array
    my @expected_listen_ports = (
        '(wickedd-d.*IPv4.*\*:68)',    # wickedddhcp4, the dhcp server.
        '(wickedd-d.*IPv6.*:\d+)',    # wickedd-dhcp6
        '(sshd.*:22 \(LISTEN\))',    # The ssh server
        '(master.*localhost:25 \(LISTEN\))',    # /usr/lib/postfix/bin//master
        '(sshd.*s390kvm.*openqaworker.*\(ESTABLISHED\))',    # ssh connection s390x
        '(systemd.*:5901 \(LISTEN\))',    # vnc on s390x
        '(sshd.*\(ESTABLISHED\))');    # ssh connection to test system
    script_run('printf "\n#expected_listen_ports:\n' . Dumper(\@expected_listen_ports) . '\n" >> ' . $test_log . '');

    my $regex = join('|', @expected_listen_ports);
    my $output = script_output('lsof -i -P');
    script_run('printf "\nlsof -i -P output:\n' . $output . '\n" >> ' . $test_log . '');
    my @lines = split(/\n/, $output);
    foreach my $port (@lines) {
        if ($port =~ /^COMMAND/) {
            # Skip title
            next;
        }
        elsif ($port =~ /$regex/) {
            record_info($port, 'This is an expected listening port');
            script_run('printf "\nThis is an expected listening port:' . $port . '" >> ' . $test_log . '');
        }
        else {
            record_info($port, 'This is not an expected listening port', result => 'fail');
            $self->result('fail');
        }
    }
    upload_log_file($test_log);
}

1;
