# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked wicked-service
# Summary: Regression test for boo#1212806 (Default route is missing
#          when gateway has a host route)
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>


use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;

    my $ip = $self->get_ip(type => 'host');
    my $ifc = $ctx->iface();
    $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $ifc, <<EOT);
BOOTPROTO='static'
STARTMODE='auto'
IPADDR='136.243.128.214'
REMOTE_IPADDR='192.168.128.1'
EOT
    $self->write_cfg('/etc/sysconfig/network/ifroute-' . $ifc, <<EOT);
default 192.168.128.1 - $ifc
EOT

    $self->wicked_command('ifup', $ifc);
    $self->assert_wicked_state(iface => $ifc);
    validate_script_output("ip -4 route show", sub { m/default via 192\.168\.128\.1 dev $ifc/ });
}

sub test_flags {
    return {always_rollback => 1};
}

1;
