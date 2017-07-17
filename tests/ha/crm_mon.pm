# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check cluster status in crm_mon
# Maintainer: Denis Zyuzin <dzyuzin@suse.com>

use base "hacluster";
use strict;
use testapi;
use autotest;
use lockapi;

sub run {
    type_string "crm_mon -1\n";
    assert_script_run q(crm_mon -1 | grep 'partition with quorum');
    assert_script_run q(crm_mon -s | grep "`crm node list | wc -l` nodes online");
}

sub test_flags {
    return {fatal => 1};
}

1;
