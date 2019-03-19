# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Advanced test cases for wicked
# Test 10: Create a tap interface from Wicked XML files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;
use utils 'file_content_replace';

sub run {
    my ($self)         = @_;
    my $config         = '/etc/sysconfig/network/ifcfg-tap1';
    my $openvpn_server = '/etc/openvpn/server.conf';
    record_info('Info', 'Create a TAP interface from Wicked XML files');
    $self->get_from_data('wicked/ifcfg/tap1_ref',      $config);
    $self->get_from_data('wicked/openvpn/server.conf', $openvpn_server);
    file_content_replace($openvpn_server, device => "tap1");
    $self->setup_tuntap($config, 'tap1');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
