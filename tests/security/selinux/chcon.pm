# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "# chcon" can change file security context
# Maintainer: QE Security <none@suse.de>
# Tags: poo#66093, tc#1741289

use base "selinuxtest";
use power_action_utils "power_action";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;
    my $test_dir = "/testdir";
    my $test_file = "testfile";
    my $fcontext_type1 = "etc_t";
    my $fcontext_type2 = "bin_t";

    $self->select_serial_terminal;

    # create a testing directory/file
    $self->create_test_file("$test_dir", "$test_file");

    # test "# chcon" can change file security context
    assert_script_run("chcon -t $fcontext_type1 ${test_dir}/${test_file}");
    validate_script_output("ls -Z ${test_dir}/${test_file}", sub { m/$fcontext_type1/ });
    assert_script_run("chcon -t $fcontext_type2 ${test_dir}/${test_file}");
    validate_script_output("ls -Z ${test_dir}/${test_file}", sub { m/$fcontext_type2/ });
}

1;
