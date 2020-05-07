# SUSE's openQA tests
#
# Copyright © 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: this test checks that YaST Command Line Keyboard module is behaving
#          correctly by changing keyboard layout and verifying that
#          they have been successfully set.
# - Set keyboard layout to korean and validate.
# - Set keyboard layout to german.
# - Restore keyboard settings to english-us and verify (enter using german characters).
# Maintainer: Ming Li <mli@suse.com>

=head1 Create regression test for keyboard layout and verify

Reference:
https://www.suse.com/documentation/sles-15/singlehtml/book_sle_admin/book_sle_admin.html#id-1.3.3.6.13.6.17

1. Set keyboard layout to korean and validate.
2. Set keyboard layout to german.
3. Restore keyboard settings to english-us and verify (enter using german characters).

=cut

use base 'y2_module_basetest';
use strict;
use warnings;
use testapi;
use utils qw(zypper_call);
use version_utils qw(is_sle);

sub run {

    select_console("root-console");

    # Set keyboard layout to korean and validate.
    zypper_call("in yast2-country", timeout => 480);
    assert_script_run("yast keyboard list");
    assert_script_run("yast keyboard set layout=korean");
    validate_script_output("yast keyboard summary 2>&1", sub { m/korean/ }, timeout => 90);

    # Set keyboard layout to german.
    assert_script_run("yast keyboard set layout=german");

    # Restore keyboard settings to english-us and verify(enter using german characters).
    if (is_sle('15-sp2+')) {
        type_string("zast kezboard set lazout)english/us\n", wait_still_screen => 3, timeout => 7);
    }
    else {
        record_soft_failure('bsc#1170292');
        type_string("zast kezboard set lazout)english/us\n", wait_still_screen => 60, timeout => 130);
    }
    save_screenshot;

    validate_script_output("yast keyboard summary 2>&1", sub { m/english-us/ }, timeout => 90);

}

1;
