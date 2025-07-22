# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary:  the step to install testsuite from QA:Head
# Maintainer: Yong Sun <yosun@suse.com>

use base "opensusebasetest";
use utils;
use testapi;

sub run {
    my $test = get_required_var('QA_TESTSUITE');
    record_info("Repo", "The corresponding repository can be found at http://build.suse.de/package/show/QA:Head/qa_test_$test");
    record_info("sources", "The corresponding test sources can be found at https://github.com/SUSE/qa-testsuites/tree/master/tests/qa_test_$test");
    zypper_call("in 'qa_test_$test'");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
