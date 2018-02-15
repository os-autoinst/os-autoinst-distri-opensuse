# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
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
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, Sebastian Chlad <schlad@suse.de>

use base 'wickedbase';
use strict;
use testapi;
use utils qw(systemctl arrays_differ);

sub run {
    my ($self) = @_;
    my $iface = script_output('ls /sys/class/net/ | grep -v lo | head -1');
    record_info('Test 1', 'Bring down the wicked client service');
    systemctl('stop wicked.service');
    $self->assert_wicked_state(wicked_client_down => 1, interfaces_down => 1);
    record_info('Test 2', 'Bring up the wicked client service');
    systemctl('start wicked.service');
    $self->assert_wicked_state();
    record_info('Test 3', 'Bring down the wicked server service');
    systemctl('stop wickedd.service');
    $self->assert_wicked_state(wicked_daemon_down => 1);
    assert_script_run("! ifdown $iface");
    record_info('Test 4', 'Bring up the wicked server service');
    systemctl('start wickedd.service');
    $self->assert_wicked_state();
    assert_script_run("ifup $iface");
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
    assert_script_run("ifdown $iface");
    assert_script_run("ping -q -c1 -W1 -I $iface 10.0.2.2 2>&1 | grep -q ' Network is unreachable'");
    assert_script_run("! \$(ip address show dev $iface | grep -q 'inet')");
    record_info('Test 7', 'Bring an interface up with wicked');
    assert_script_run("ifup $iface");
    assert_script_run("ping -q -c1 -W1 -I $iface 10.0.2.2");
    validate_script_output("ip address show dev $iface", sub { m/(?=inet)(?=[dhcp])/g; });
    $self->save_and_upload_wicked_log();
}

1;
