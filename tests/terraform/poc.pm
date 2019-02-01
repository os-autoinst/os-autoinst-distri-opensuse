# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Terraform POC
#          It creates VMs on a remote machine and runs some commands it them
#
# Maintainer: Jose Lausuch <jalausuch@suse.de>

use base "terraform::basetest";
use testapi;
use strict;

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    my @vms = $self->deploy_test_env('terraform/poc/poc.tf');
    record_info('INFO', 'VM1 : ' . $vms[0]->domain_name . "\nIP1:  " . $vms[0]->domain_ip . "\n\nVM2 " . $vms[1]->domain_name . "\nIP1:  " . $vms[1]->domain_ip);

    my $output = $vms[0]->run_command(cmd => 'ls -lh');
    record_info('CMD', 'Output of command "ls -lh" on vm ' . $vms[0]->domain_name . ":\n$output");

    my $cmd = 'ping -c 1 ' . $vms[1]->domain_ip;
    $output = $vms[0]->run_command(cmd => $cmd, wait_time => 10);
    record_info('PING', "VM1 pings VM2\n\nCMD: $cmd\n\nOUTPUT:\n$output");

    $cmd    = 'ping -c 1 ' . $vms[0]->domain_ip;
    $output = $vms[1]->run_command(cmd => $cmd, wait_time => 10);
    record_info('PING', "VM2 pings VM1\n\nCMD: $cmd\n\nOUTPUT:\n$output");
}

1;
