# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: A simple 32bit C++ program to test 32bit runtime on x64 system
# Maintainer: Nathan Zhao <jtzhao@suse.com>

use base "qa_run";
use strict;
use warnings;
use testapi;

sub test_run_list {
    return qw(_reboot_off cpp_32bit);
}

sub test_suite {
    return 'regression';
}

sub junit_type {
    return 'user_regression';
}

1;

