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
# Summary: Test "# chcat" can change file SELinux security category
#          NOTE: Since we only focus on minimum policy and this cmd is
#                for "mls", so this case only do some basic testings.
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#66096, tc#1745369

use base "selinuxtest";
use power_action_utils "power_action";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self)    = shift;
    my $test_dir  = "/testdir";
    my $test_file = "testfile";
    my $test_user = "root";

    my $systemlow            = "s0";
    my $systemlow_systemhigh = "s0-s0:c0.c1023";
    my $systemhigh           = "s0:c0.c1023";
    my $test_category        = "c0.c1023";

    my $default_category_root       = $systemhigh;
    my $default_category_commonfile = $systemlow;

    select_console "root-console";

    # create a testing directory/file
    $self->create_test_file("$test_dir", "$test_file");

    # test "# chcat -L" can list available categories
    validate_script_output(
        "chcat -L",
        sub {
            m/
	    $systemlow\ .*SystemLow.*
            $systemlow_systemhigh\ .*SystemLow-SystemHigh.*
            $systemhigh\ .*SystemHigh/sx
        });

    # test "# chcat [+|-]CATEGORY File" can operate categories on dirs/files
    # on dirs
    $self->check_category("$test_dir", "$systemlow");
    assert_script_run("chcat +${test_category} $test_dir");
    $self->check_category("$test_dir", "$systemhigh");
    assert_script_run("chcat -- -${test_category} $test_dir");
    $self->check_category("$test_dir", "$systemlow");
    # on files
    $self->check_category("${test_dir}/${test_file}", "$systemlow");
    assert_script_run("chcat +${test_category} ${test_dir}/${test_file}");
    $self->check_category("${test_dir}/${test_file}", "$systemhigh");
    assert_script_run("chcat -d ${test_dir}/${test_file}");
    $self->check_category("${test_dir}/${test_file}", "$systemlow");

    # test "# chcat -l" can operate categories on users instead of files
    validate_script_output("chcat -L -l $test_user", sub { m/${test_user}:\ .*${default_category_root}$/ });
    assert_script_run("chcat -l -d $test_user");
    validate_script_output("chcat -L -l $test_user", sub { m/${test_user}:\ .*${systemlow}$/ });
    assert_script_run("chcat -l +${test_category} $test_user");
    validate_script_output("chcat -L -l $test_user", sub { m/${test_user}:\ .*${default_category_root}$/ });
}

1;
