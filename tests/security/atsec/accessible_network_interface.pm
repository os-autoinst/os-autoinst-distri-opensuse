# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'Accessible network interface' test case of ATSec test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#111899

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use atsec_test;
use Data::Dumper;

sub run {
    my ($self) = shift;

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

    my $regex = join('|', @expected_listen_ports);
    my $output = script_output('lsof -i -P');
    my @lines = split(/\n/, $output);
    foreach my $port (@lines) {
        if ($port =~ /^COMMAND/) {
            # Skip title
            next;
        }
        elsif ($port =~ /$regex/) {
            record_info($port, 'This is an expected listening port');
        }
        else {
            record_info($port, 'This is not an expected listening port', result => 'fail');
            $self->result('fail');
        }
    }
}

1;
