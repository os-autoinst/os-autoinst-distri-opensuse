# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Advanced test cases for wicked
# Test scenarios:
# Test 1 : Reference GRE interface
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, Jose Lausuch <jalausuch@suse.com>

use base 'wickedbase';
use strict;
use testapi;
use utils 'systemctl';
use lockapi;
use mmapi;

sub create_tunnel_with_commands {
    my ($self, $type, $sub_mask) = @_;
    my $local_ip  = $self->get_ip(no_mask => 1, is_wicked_ref => 1, type => 'host');
    my $remote_ip = $self->get_ip(no_mask => 1, is_wicked_ref => 0, type => 'host');
    my $tunnel_ip = $self->get_ip(is_wicked_ref => 1, type => $type);
    my $mode = substr($type, 0, -1);
    assert_script_run("ip tunnel add $type mode $mode remote $remote_ip local $local_ip");
    assert_script_run("ip link set $type up");
    assert_script_run("ip addr add $tunnel_ip/$sub_mask dev $type");
    assert_script_run("ip addr");
}

sub run {
    my ($self) = @_;
    record_info('Test 1', 'Create a gre interface with IP commands');
    $self->create_tunnel_with_commands("gre1", "24");
    # Lock until parent creates mutex 'test_1_ready'
    mutex_lock('test_1_ready');
    # Unlock mutex to end test
    mutex_unlock('test_1_ready');
    assert_script_run("ifdown gre1");

    record_info('Test 3', 'Create a SIT interface with IP commands');
    $self->create_tunnel_with_commands("sit1", "127");
    # Lock until parent creates mutex 'test_1_ready'
    mutex_lock('test_3_ready');
    # Unlock mutex to end test
    mutex_unlock('test_3_ready');

}

1;

