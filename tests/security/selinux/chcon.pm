# Copyright (C) 2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Test "# chcon" can change file security context
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#66093, tc#1741289

use base "selinuxtest";
use power_action_utils "power_action";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self)         = shift;
    my $test_dir       = "/testdir";
    my $test_file      = "testfile";
    my $fcontext_type1 = "etc_t";
    my $fcontext_type2 = "bin_t";

    select_console "root-console";

    # create a testing directory/file
    $self->create_test_file("$test_dir", "$test_file");

    # test "# chcon" can change file security context
    assert_script_run("chcon -t $fcontext_type1 ${test_dir}/${test_file}");
    validate_script_output("ls -Z ${test_dir}/${test_file}", sub { m/$fcontext_type1/ });
    assert_script_run("chcon -t $fcontext_type2 ${test_dir}/${test_file}");
    validate_script_output("ls -Z ${test_dir}/${test_file}", sub { m/$fcontext_type2/ });
}

1;
