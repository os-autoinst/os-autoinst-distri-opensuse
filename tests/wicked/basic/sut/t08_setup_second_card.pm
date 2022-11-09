# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Set up a second card
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;
use lockapi;

sub run {
    my ($self, $ctx) = @_;

    sleep(30);    # OVS on a worker is slow sometimes to change and we haven't found better way how to handle it

    my $cfg_ifc1 = '/etc/sysconfig/network/ifcfg-' . $ctx->iface();
    my $cfg_ifc2 = '/etc/sysconfig/network/ifcfg-' . $ctx->iface2();
    my $dhcp_ip_sut = $self->get_ip(type => 'dhcp_2nic');
    my $dhcp_ip_ref = $self->get_ip(type => 'dhcp_2nic', is_wicked_ref => 1);
    my $static_ip_sut = $self->get_ip(type => 'second_card');
    my $static_ip_ref = $self->get_ip(type => 'second_card', is_wicked_ref => 1);

    record_info('Info', 'Set up a second card');
    $self->get_from_data('wicked/dynamic_address/ifcfg-eth0', $cfg_ifc1);
    $self->get_from_data('wicked/static_address/ifcfg-eth0_second_card', $cfg_ifc2);
    assert_script_run('echo "default ' . $static_ip_ref . ' - -" > /etc/sysconfig/network/routes');
    mutex_wait('dhcpdbasict08');

    # the timeout of 60 is a temporarly solution see: https://progress.opensuse.org/issues/89269#note-4
    $self->wicked_command('ifup --timeout 60', $ctx->iface());
    $self->wicked_command('ifup --timeout 60', $ctx->iface2());

    my $ip_iface1 = $self->get_current_ip($ctx->iface());
    my $ip_iface2 = $self->get_current_ip($ctx->iface2());
    die("Unexpected IP $ip_iface1 on " . $ctx->iface()) unless ($ip_iface1 =~ /$dhcp_ip_sut/);
    die("Unexpected IP $ip_iface2 on " . $ctx->iface2()) unless ($ip_iface2 eq $static_ip_sut);

    $self->ping_with_timeout(type => 'dhcp_2nic', interface => $ctx->iface());
    $self->ping_with_timeout(type => 'second_card', interface => $ctx->iface2());
}

sub test_flags {
    return {always_rollback => 1};
}

1;
