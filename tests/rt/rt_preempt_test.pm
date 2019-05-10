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
    script_run "zypper -q ar http://download.suse.de/ibs/Devel:/RTE:/SLE12SP1/standard/Devel:RTE:SLE12SP1.repo";
    script_run "zypper -q --gpg-auto-import-keys refresh";
    script_run "zypper -q --non-interactive install preempt-test";

    assert_script_run "preempt-test | grep 'Test PASSED'";
}

1;
