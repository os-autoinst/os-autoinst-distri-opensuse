# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Add ports to zone, as specified in test data, using firewall-cmd.
# The ports added can be descriped by a range of ports or a singe port number.
#
# test_data:
#   port: 3990-3999
#   zone: public
#
# In case of failure, the test will die.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use base 'consoletest';
use warnings;
use testapi;
use scheduler 'get_test_suite_data';
use Utils::Firewalld qw(add_port_to_zone reload_firewalld);

sub run {
    my $test_data = get_test_suite_data();
    select_console 'root-console';
    add_port_to_zone({zone => $test_data->{zone}, port => $test_data->{port}});
    reload_firewalld();
}

sub test_flags {
    return {fatal => 1};
}

1;
