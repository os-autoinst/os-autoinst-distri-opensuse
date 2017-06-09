# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test an arbitrary package with an arbitrary test script provided
#  both by variables
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'consoletest';
use strict;
use testapi;
use utils 'zypper_call';

sub run() {
    zypper_call('ar -q ' . get_required_var('PACKAGE_TEST_REPO')) if get_var('PACKAGE_TEST_REPO');
    zypper_call('in ' . get_required_var('PACKAGE_TEST_PACKAGE'));
    assert_script_run 'wget ' . get_required_var('PACKAGE_TEST_TEST_URL');
    assert_script_run 'chmod +x ' . get_required_var('PACKAGE_TEST_TEST_FILENAME');
    assert_script_run './' . get_required_var('PACKAGE_TEST_TEST_FILENAME');
}

1;
