# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked wicked-service
# Summary: Check DAD (duplicate address detection) within dhcp4
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;
    my $ip = $self->get_ip(type => 'host');

    $self->get_from_data('wicked/dynamic_address/ifcfg-eth0', '/etc/sysconfig/network/ifcfg-' . $ctx->iface());
    $self->do_barrier('setup');

    $self->wicked_command('ifup', $ctx->iface());
    assert_script_run('wicked ifstatus ' . $ctx->iface());
    $self->do_barrier('ifup');

    $self->ping_with_timeout(type => 'host');
    $self->do_barrier('verify');

    # Avoid logchecker anouncing an expected error
    my $varname = 'WICKED_CHECK_LOG_EXCLUDE_' . uc($self->{name});
    set_var($varname, get_var($varname, '') . ",wickedd-dhcp4=DHCPv4 duplicate address");
}

sub test_flags {
    return {always_rollback => 1};
}

1;
