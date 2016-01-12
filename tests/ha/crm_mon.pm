# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "hacluster";
use testapi;
use autotest;
use lockapi;

sub run() {
    type_string "crm_mon -1\n";
    assert_screen "ha-crm-mon-" . get_var("CLUSTERNAME");
}

sub test_flags {
    return {fatal => 1};
}

1;
