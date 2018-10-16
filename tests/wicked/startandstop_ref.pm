# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Startandstop test cases for wicked. Reference machine which used to
#          support tests running on SUT
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use testapi;
use utils 'systemctl';
use lockapi;
use mmapi;

sub run {
    my ($self) = @_;
    my $openvpn_server = '/etc/openvpn/server.conf';

    record_info('Test 1', 'Bridge - ifreload');
    mutex_wait('test_1_ready');

    record_info('Test 2', 'Bridge - ifup, ifreload');
    mutex_wait('test_2_ready');

    record_info('Test 3', 'Bridge - ifup, remove all config, ifreload');
    mutex_wait('test_3_ready');

    record_info('Test 4', 'Bridge - ifup, remove one config, ifreload');
    mutex_wait('test_4_ready');

    record_info('Test 5', 'Standalone card - ifdown, ifreload');
    mutex_wait('test_5_ready');

}

1;
