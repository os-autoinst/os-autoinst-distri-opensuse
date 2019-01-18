# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Use qa_test_php(QA:Head) to test php7 functional feature.
# Maintainer: Yong Sun <yosun@suse.com>

use base "qa_run";
use strict;
use warnings;
use testapi;

sub test_run_list {
    return qw(_reboot_off php7);
}

sub test_suite {
    return 'regression';
}

sub junit_type {
    return 'user_regression';
}

1;

