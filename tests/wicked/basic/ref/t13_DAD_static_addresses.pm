# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked wicked-service
# Summary: Check DAD (duplicate address detection)
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;

sub pre_run_hook {
    my ($self) = @_;
    $self->do_barrier_create('setup');
    $self->SUPER::pre_run_hook;
}

sub run {
    my ($self, $ctx) = @_;
    my $ip = $self->get_remote_ip(type => 'host', netmask => 1);
    record_info('Info', "Set ip $ip to force DAD detection");
    assert_script_run(sprintf(q(ip addr add dev '%s' '%s'), $ctx->iface(), $ip));
    assert_script_run(sprintf(q(ip link set dev '%s' up), $ctx->iface()));

    sleep 30 if $self->need_network_tweaks();
    $self->do_barrier('setup');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
