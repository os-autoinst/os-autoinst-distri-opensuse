# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-country
# Summary: this test checks that YaST Command Line Keyboard module is behaving
#          correctly by changing keyboard layout and verifying that
#          they have been successfully set.
# - Set keyboard layout to korean and validate.
# - Set keyboard layout to german.
# - Restore keyboard settings to english-us and verify (enter using german characters).
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

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

sub run {
    select_console("root-console");
    # Set keyboard layout to korean and validate.
    zypper_call("in yast2-country", timeout => 480);
    assert_script_run("yast keyboard list");
    assert_script_run("yast keyboard set layout=korean");
    validate_script_output("yast keyboard summary 2>&1", sub { m/korean/ }, timeout => 180);

    # Set keyboard layout to german.
    assert_script_run("yast keyboard set layout=german");

    # Restore keyboard settings to english-us and verify(enter using german characters).
    enter_cmd("zast kezboard set lazout)english/us", wait_still_screen => 10, timeout => 180);
    send_key_until_needlematch 'root-console', 'ret', 61, 5;
    validate_script_output("yast keyboard summary 2>&1", sub { m/english-us/ }, timeout => 180);
}

1;
