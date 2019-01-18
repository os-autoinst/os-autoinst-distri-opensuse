# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary:  the step to install testsuite from QA:Head
# Maintainer: Yong Sun <yosun@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use utils;
use testapi;

sub run {
    my $test = get_required_var('QA_TESTSUITE');
    record_info("Repo",    "The corresponding repository can be found at http://build.suse.de/package/show/QA:Head/qa_test_$test");
    record_info("sources", "The corresponding test sources can be found at https://github.com/SUSE/qa-testsuites/tree/master/tests/qa_test_$test");
    zypper_call("in 'qa_test_$test'");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
