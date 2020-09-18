# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run binary tests from upstream after openSUSE/SUSE patches.
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>, Thomas Blume <tblume@suse.com>

use base 'systemd_testsuite_test';
use warnings;
use strict;
use testapi;

sub run {
    # run binary tests
    assert_script_run('cd /usr/lib/systemd/tests');
    validate_script_output('./run-tests.sh | tee /tmp/testsuite.log', sub { m/# FAIL:\s*0/ }, timeout => 600);
    save_screenshot;
    script_run 'clear';
}

sub test_flags {
    return {always_rollback => 1};
}

1;
