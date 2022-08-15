# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked teamd
# Summary: Teaming, ifcfg - check port config
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use Mojo::JSON qw(decode_json);
use Mojo::JSON::Pointer;
use testapi;

sub validate_team_port_config {
    my ($self, $ctx) = @_;
    my $iface1 = $ctx->iface();
    my $iface2 = $ctx->iface2();

    $self->wicked_command('ifup', 'team0');
    $self->validate_interfaces('team0', $ctx->iface(), $ctx->iface2(), 0);
    $self->ping_with_timeout(type => 'host', interface => 'team0', count_success => 30, timeout => 4);

    # The Mojo::JSON::Pointer is a helper to search in json data, like you can do with dom objects
    my $jpointer = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')));

    my %check = (
        '/device' => 'team0',
        "/ports/$iface1/prio" => 10,
        "/ports/$iface2/prio" => 1,
        "/ports/$iface1/sticky" => undef,
        "/ports/$iface2/sticky" => Mojo::JSON->true,
    );
    while (my ($k, $v) = each(%check)) {
        my $val = $jpointer->get($k);
        die("Teamd configuration failed in $k: got:'" . ($val // 'undef') . "' expected: '" . ($v // 'undef') . "'")
          unless ((defined($val) && $val eq $v) || (!defined($val) && !defined($v)));
    }
    $self->wicked_command('ifdown', 'team0');
}

sub run {
    my ($self, $ctx) = @_;
    return if $self->skip_by_wicked_version('>=0.6.70');

    record_info('INFO', 'Teaming, ifcfg - check port config');

    my $ipaddr4 = $self->get_ip(type => 'host', netmask => 1);
    my $iface1 = $ctx->iface();
    my $iface2 = $ctx->iface2();

    $self->write_cfg('/etc/sysconfig/network/ifcfg-team0', <<EOT);
BOOTPROTO='static'
STARTMODE='auto'
IPADDR='$ipaddr4'
TEAM_RUNNER='activebackup'
TEAM_PORT_DEVICE_0='$iface1'
TEAM_PORT_DEVICE_1='$iface2'
TEAM_PORT_PRIO_0='10'
TEAM_PORT_PRIO_1='1'
TEAM_PORT_STICKY_1='true'
EOT
    # Sanity check: we do _not_ have a port configuration for both slave ports!
    assert_script_run("! test -e /etc/sysconfig/network/ifcfg-$iface1");
    assert_script_run("! test -e /etc/sysconfig/network/ifcfg-$iface2");
    $self->validate_team_port_config($ctx);

    # Same test, but with ifcfg files for each slave interface
    $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $_, <<EOT) foreach ($iface1, $iface2);
BOOTPROTO=none
STARTMODE=hotplug
EOT
    $self->validate_team_port_config($ctx);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
