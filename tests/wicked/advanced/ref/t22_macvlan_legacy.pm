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

    my $remote_ip = $self->get_remote_ip(type => 'host');
    my $local_ip = $self->get_ip(type => 'host', netmask => 1);

    $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $ctx->iface(), <<EOT);
STARTMODE=auto
BOOTPROTO=static
IPADDR=$local_ip
EOT

    $self->wicked_command('ifup', $ctx->iface());
    $self->ping_with_timeout(type => 'host');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
