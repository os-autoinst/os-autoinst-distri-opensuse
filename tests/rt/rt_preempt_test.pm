# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: RT preempt test
# Maintainer: QE Kernel <kernel-qa@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils qw(zypper_call);
use repo_tools qw(add_qa_head_repo);

# Run preempt test
sub run {
    add_qa_head_repo;
    zypper_call "install preempt-test";
    assert_script_run "preempt-test | tee ~/preempt.out";
    assert_script_run "grep \'Test PASSED\' ~/preempt.out && rm -f ~/preempt.out";
}

1;
