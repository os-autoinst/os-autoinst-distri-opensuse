# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Switch crypto-policies, reboot and verify sshd is running
# Maintainer: QE Security <none@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use power_action_utils 'power_action';
use Utils::Backends 'is_pvm';
use Utils::Architectures;

sub run {
    my ($self) = @_;
    my @services = qw{sshd named};
    select_serial_terminal;
    setup_bind();
    foreach my $s (@services) {
        systemctl "enable --now $s.service";
    }
    for my $policy ('LEGACY', 'BSI', 'FUTURE', 'DEFAULT') {
        $self->set_policy($policy);
        # check the services are running after policy change
        foreach my $s (@services) {
            validate_script_output "systemctl status $s.service", sub { m/active \(running\)/ };
        }
        ensure_bind_is_working();
    }
}

sub setup_bind {
    zypper_call 'in bind';
    assert_script_run('curl ' . data_url('security/crypto_policies/example.com.zone') . ' -o /var/lib/named/master/example.com');
    assert_script_run('curl ' . data_url('security/crypto_policies/example.com.conf') . ' -o /etc/named.d/example.com.conf');
    assert_script_run qq(echo 'include "/etc/named.d/example.com.conf";' >> /etc/named.conf);
}

# simple smoke tests
sub ensure_bind_is_working {
    # validate root DNS signature
    validate_script_output 'delv', sub { m/fully validated/ };
    # query rndc (uses crypto key authentication)
    validate_script_output 'rndc status', sub { m/server is up and running/ };
    # query local authoritative zone
    validate_script_output 'host foobar.example.com localhost', sub { m /foobar.example.com has address 1.2.3.4/ };
}

sub set_policy {
    my ($self, $policy) = @_;
    assert_script_run "update-crypto-policies --set $policy";
    power_action('reboot', textmode => 1);
    reconnect_mgmt_console if is_pvm();
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    select_serial_terminal;
    # ensure the current policy has been applied
    validate_script_output 'update-crypto-policies --show', sub { m/$policy/ };
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
