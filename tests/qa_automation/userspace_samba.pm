# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Runs samba qa testsuite
# Maintainer: Ednilson Miura <emiura@suse.com>

use base "qa_run";
use strict;
use testapi;

sub test_run_list {
    return qw(_reboot_off samba);
}

sub test_suite {
    return 'regression';
}

sub junit_type {
    return 'user_regression';
}

1;
