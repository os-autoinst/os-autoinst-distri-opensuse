# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: yast2-sysconfig
# Summary: yast sysconfig in cli, clears, details, lists and sets the
#          variables in /etc/sysconfig.
# Maintainer: Jun Wang <jgwang@suse.com>
#
#
# This PM is to test the functions of yast2-sysconfig in cli mode
#
#     list, details, set, clear
#
# which follow the link:
# https://www.suse.com/documentation/sles-15/singlehtml/book_sle_admin/book_sle_admin.html#id-1.3.3.6.13.6.31.
#
# the test method:
#     1. create a sysconfig file
#     2. run sysconfig command
#     3. verify the above the sysconfig command.
#
# case: a normal sysconfig file
#
#     1. create a tmp sysconfig file
#
#         ## Type:    string
#         ## Default: ""
#         #
#         # This variable just is used for testing yast sysconfig
#         # in cli mode.
#         XXX_YYY="ZZZ"
#
#     2. run sysconfig command:
#         1) list
#               command:
#                   # yast sysconfig list all
#               expection:
#                   XXX_YYY="ZZZ"
#         2) details
#               command:
#                   # yast sysconfig details variable=XXX_YYY$<path of test file>
#               expection:
#                   these items are correct:
#                       Value: ZZZ
#                       File: <path of test file>
#                       Description: This variable just is used for testing yast sysconfig
#         3) set
#               command:
#                   # yast sysconfig set XXX_YYY$<path of test file>=AAA
#                   # yast sysconfig details variable=XXX_YYY$<path of test file>
#               expection:
#                   "details" command get the expection result: AAA
#         4) clear
#               command:
#                   # yast sysconfig clear variable=XXX_YYY$<path of test file>
#                   # yast sysconfig details variable=XXX_YYY$<path of test file>
#               expection:
#                   "details" command get a null value.

use base 'y2_module_basetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

# this is a tmp file for testing
my $creat_tmp_file = 'cat > /etc/sysconfig/my_test_file << EOF
## Type:    string
## Default: ""
#
# This variable just is used for testing yast sysconfig
# in cli mode.
XXX_YYY="ZZZ"

EOF
(exit $?)';

sub run {
    select_serial_terminal;

    # make sure the package was installed.
    zypper_call("in yast2-sysconfig", exitcode => [0, 102, 103]);

    # create a tmp file for testing
    assert_script_run("$creat_tmp_file", fail_message => "Creating tmp file failed.");

    # check yast sysconfig list
    validate_script_output 'yast sysconfig list all 2>&1', sub { m/XXX_YYY="ZZZ"/; };

    # check yast sysconfig details
    # verify decription, file name, value of the specific variable XXX_YYY.
    validate_script_output 'yast sysconfig details variable=XXX_YYY$/etc/sysconfig/my_test_file 2>&1',
      sub { m/testing yast sysconfig/; m!File: /etc/sysconfig/my_test_file!; m/\nValue: ZZZ/; };

    # check yast sysconfig set
    assert_script_run("yast sysconfig set XXX_YYY=AAA", fail_message => "yast sysconfig set failed.");
    validate_script_output 'yast sysconfig details variable=XXX_YYY$/etc/sysconfig/my_test_file 2>&1', sub { m/\nValue: AAA/; };

    # check yast sysconfig clear
    assert_script_run("yast sysconfig clear variable=XXX_YYY", fail_message => "yast sysconfig clear failed.");
    validate_script_output 'yast sysconfig details variable=XXX_YYY$/etc/sysconfig/my_test_file 2>&1', sub { m/\nValue: /; };

    # delete the tmp file for testing
    assert_script_run("rm -f /etc/sysconfig/my_test_file", fail_message => "deleting tmp file failed.");
}

1;
