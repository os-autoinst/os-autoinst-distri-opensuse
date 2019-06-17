# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: RT preempt test
# Maintainer: mkravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

# Run preempt test
sub run {
    select_console 'root-console';
    script_run "zypper -q ar http://download.suse.de/ibs/Devel:/RTE:/SLE12SP1/standard/Devel:RTE:SLE12SP1.repo";
    script_run "zypper -q --gpg-auto-import-keys refresh";
    script_run "zypper -q --non-interactive install preempt-test";
    assert_script_run "preempt-test | tee ~/preempt.out";
    assert_script_run "grep \'Test PASSED\' ~/preempt.out && rm -f ~/preempt.out";
}

1;
