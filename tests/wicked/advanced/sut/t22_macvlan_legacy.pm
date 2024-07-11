# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Advanced test cases for wicked
# Test 22: Create MACVLAN device on SUT and use ping to validate connection
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;

    my $local_ip = $self->get_ip(type => 'host', netmask => 1);
    my $device = $ctx->iface();

    $self->write_cfg('/etc/sysconfig/network/ifcfg-macvlan1', <<EOT);
STARTMODE=auto
BOOTPROTO=static
IPADDR=$local_ip
MACVLAN_DEVICE='$device'
EOT

    $self->wicked_command('ifup', 'macvlan1');
    $self->ping_with_timeout(type => 'host');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
