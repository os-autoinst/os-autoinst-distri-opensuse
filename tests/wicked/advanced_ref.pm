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
# Maintainers:
#     Anton Smorodskyi <asmorodskyi@suse.com>
#     Jose Lausuch <jalausuch@suse.com>

use base 'wickedbase';
use strict;
use testapi;
use utils 'systemctl';
use lockapi;
use mmapi;

sub run {
    my ($self) = @_;
    record_info('Test 1', 'Create a gre interface with IP commands');
    my $ip_no_mask               = $self->get_ip(no_mask => 1, is_wicked_ref => 1, type => 'host');
    my $parallel_host_ip_no_mask = $self->get_ip(no_mask => 1, is_wicked_ref => 0, type => 'host');
    my $ip_in_tunnel          = $self->get_ip(is_wicked_ref => 1, type => 'gre_tunnel_ip');
    my $parallel_ip_in_tunnel = $self->get_ip(is_wicked_ref => 0, type => 'gre_tunnel_ip');
    $self->create_tunnel_with_commands(
        mode      => "gre",
        interface => "gre1",
        remote_ip => "$parallel_host_ip_no_mask",
        local_ip  => "$ip_no_mask",
        tunnel_ip => "$ip_in_tunnel/24"
    );
    # Lock until parent creates mutex 'test_1_ready'
    mutex_lock('test_1_ready');
    # Unlock mutex to end test
    mutex_unlock('test_1_ready');

    record_info('Test 3', 'Create a SIT interface with IP commands');
    my $ip_in_tunnel          = $self->get_ip(is_wicked_ref => 1, type => 'sit_tunnel_ip');
    my $parallel_ip_in_tunnel = $self->get_ip(is_wicked_ref => 0, type => 'sit_tunnel_ip');
    $self->create_tunnel_with_commands(
        mode      => "sit",
        interface => "sit1",
        remote_ip => "$parallel_host_ip_no_mask",
        local_ip  => "$ip_no_mask",
        tunnel_ip => "$ip_in_tunnel/127"
    );
    # Lock until parent creates mutex 'test_1_ready'
    mutex_lock('test_3_ready');
    # Unlock mutex to end test
    mutex_unlock('test_3_ready');

}

1;

