# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Sanity checks of wicked
# Test scenarios:
# Test 1: Bring down the wicked client service
# Test 2: Bring up the wicked client service
# Test 3: Bring down the wicked server service
# Test 4: Bring up the wicked server service
# Test 5: List the network interfaces with wicked
# Test 6: Bring an interface down with wicked
# Test 7: Bring an interface up with wicked

# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;
use utils qw(systemctl arrays_differ);

sub run {
    my ($self, $ctx) = @_;
    record_info('Test 1', 'Bring down the wicked client service');
    systemctl('stop wicked.service');
    $self->assert_wicked_state(wicked_client_down => 1, interfaces_down => 1, iface => $ctx->iface());
    record_info('Test 2', 'Bring up the wicked client service');
    systemctl('start wicked.service');
    $self->assert_wicked_state(iface => $ctx->iface());
    record_info('Test 3', 'Bring down the wicked server service');
    systemctl('stop wickedd.service');
    $self->assert_wicked_state(wicked_daemon_down => 1, iface => $ctx->iface());
    assert_script_run('! ifdown ' . $ctx->iface());
    record_info('Test 4', 'Bring up the wicked server service');
    systemctl('start wickedd.service');
    $self->assert_wicked_state(iface => $ctx->iface());
    record_info('Test 5', 'List the network interfaces with wicked');
    my @wicked_all_ifaces = split("\n", script_output('wicked show --brief all'));
    foreach (@wicked_all_ifaces) {
        $_ = substr($_, 0, index($_, ' '));
    }
    my @ls_all_ifaces = split(' ', script_output('ls /sys/class/net/'));
    if (arrays_differ(\@wicked_all_ifaces, \@ls_all_ifaces)) {
        diag "expected list of interfaces: @wicked_all_ifaces";
        diag "actual list of interfaces: @ls_all_ifaces";
        die "Wrong list of interfaces from wicked";
    }
    record_info('Test 6', 'Bring an interface down with wicked');
    $self->wicked_command('ifdown', $ctx->iface());
    die('IP should not be reachable') if ($self->ping_with_timeout(ip => '10.0.2.2', timeout => '2', proceed_on_failure => 1));
    die if ($self->get_current_ip($ctx->iface()));
    record_info('Test 7', 'Bring an interface up with wicked');
    $self->wicked_command('ifup', $ctx->iface());
    $self->ping_with_timeout(ip => '10.0.2.2');
    validate_script_output('ip address show dev ' . $ctx->iface(), sub { m/inet/g; });
    validate_script_output('wicked show dev ' . $ctx->iface(),     sub { m/\[dhcp\]/g; });
}

sub test_flags {
    return {always_rollback => 1};
}

1;
