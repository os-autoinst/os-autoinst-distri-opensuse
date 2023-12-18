# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Package for ssh cryptographic policy testing
#
# Maintainer: George Gkioulis <ggkioulis@suse.com>

package ssh_crypto_policy;
use base 'consoletest';
use testapi;
use utils;
use strict;
use warnings;

sub new() {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new();
    $self->{name} = $args{name};
    $self->{query} = $args{query};
    $self->{cmd_option} = $args{cmd_option};
    $self->{algorithm_array} = ();

    # In the case of HostKeyAlgorithms, get only the ones provided by the server side
    if ($self->{name} eq "HostKeyAlgorithms") {
        $self->create_host_key_algorithm_array();
    } else {
        # Split the output of the ssh algorithm query to an array
        $self->{algorithm_array} = [split(/\n/, script_output("ssh -Q $self->{query}"))];
    }

    return $self;
}

sub create_host_key_algorithm_array() {
    my ($self) = @_;

    # If nmap is not installed, install it
    if (script_run("which nmap")) {
        zypper_call("in nmap");
    }

    # Get all the algorithms supported by the server side
    my $output = script_output("nmap --script ssh2-enum-algos -sV -p 22 localhost");
    my @output_lines = split('\|', $output);

    my $parse_algorithms = 0;
    foreach my $line (@output_lines) {
        if ($parse_algorithms) {
            # If line contains the string "encryption algorithms", you can finish parsing
            last if (index($line, "encryption_algorithms") != -1);
            # Get the host key algorithms
            $line =~ s/^\s+|\s+$//g;
            push(@{$self->{algorithm_array}}, $line);
        } elsif (index($line, "server_host_key_algorithms") != -1) {
            # If line contains the string server_host_key_algorithms, start parsing
            $parse_algorithms = 1;
        }
    }
}

sub add_to_sshd_config() {
    my ($self) = @_;

    # Create the config line that allows all the available algorithms
    # An example config can be "Ciphers aes128-ctr,aes192-ctr,aes256-ctr"
    my $config_line = $self->{name} . ' ' . join(",", @{$self->{algorithm_array}});

    assert_script_run("(echo '$config_line' && cat /etc/ssh/sshd_config) > /etc/ssh/sshd_config_");
    assert_script_run("mv /etc/ssh/sshd_config_ /etc/ssh/sshd_config");
}

sub test_algorithms() {
    my ($self, %args) = @_;
    my $remote_user = $args{remote_user};

    my %failing_algorithms = (
        "gss-gex-sha1-" => 1,
        "gss-group1-sha1-" => 1,
        "gss-group14-sha1-" => 1);

    for my $algorithm (@{$self->{algorithm_array}}) {
        if (exists $failing_algorithms{$algorithm}) {
            record_soft_failure("$algorithm ($self->{name}) fails with unexpected internal error bsc#1182601");
            next;
        }

        if ($algorithm eq "ssh-dss") {
            # In case that ssh-dss is available, make sure to explicitly add the dsa host key to known hosts
            assert_script_run("ssh-keyscan -t dsa localhost >> ~/.ssh/known_hosts");
        }

        record_info($self->{name}, $algorithm);
        assert_script_run("ssh $self->{cmd_option}$algorithm $remote_user\@localhost bash -c 'whoami| grep $remote_user'");
    }
}

1;
