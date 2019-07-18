# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validate if generated autoyast profile corresponds to the expected one
#          when using disks as Multiple Device member.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

use strict;
use warnings;
use base 'basetest';
use testapi;
use xml_utils;
use scheduler 'get_test_data';
use Test::Assert ':all';
use autoyast 'init_autoyast_profile';

sub run {
    my $test_data = get_test_data();                     # get test data from scheduling yaml file
    my $xpc       = get_xpc(init_autoyast_profile());    # get XPathContext

    record_info('RAID level', 'Verify that raid level in the generated autoyast profile corresponds to the expected one.');
    my @raid_level_nodes = find_nodes(xpc => $xpc, xpath => $test_data->{xpath}->{raid_type});
    assert_equals($test_data->{raid_level}, $raid_level_nodes[0]->to_literal, 'Wrong raid level is specified for the MD.');

    record_info('Mount points', 'Verify that generated autoyast profile contains the the expected number of mount points.');
    my @mount_point_nodes = find_nodes(xpc => $xpc, xpath => $test_data->{xpath}->{mount});
    assert_equals($test_data->{partitions_count}, scalar @mount_point_nodes, 'MD RAID contains wrong number of mount points.');
}

1;
