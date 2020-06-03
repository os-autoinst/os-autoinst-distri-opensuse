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
# Summary: Test "#semanage fcontext" command with options
#          "-D / -a / -m ..." can work
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#65669, tc#1741290

use base "selinuxtest";
use power_action_utils "power_action";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self)                = shift;
    my $file_contexts_local   = $selinuxtest::file_contexts_local;
    my $test_boolean          = "fips_mode";
    my $test_dir              = "/testdir";
    my $test_file             = "testfile";
    my $fcontext_type_default = "default_t";                         # or, "user_tmp_t";
    my $fcontext_type1        = "etc_t";
    my $fcontext_type2        = "bin_t";
    my $fcontext_type3        = "var_t";

    select_console "root-console";

    # create a testing directory/file
    $self->create_test_file("$test_dir", "$test_file");

    # clean up in case: remove all local customizations
    assert_script_run("semanage fcontext -D");

    # test option "-a -t": add local customizations
    assert_script_run("semanage fcontext -a -t $fcontext_type1 $test_dir");
    assert_script_run("semanage fcontext -a -t $fcontext_type2 ${test_dir}/${test_file}");

    # check contexts file
    validate_script_output(
        "cat $file_contexts_local",
        sub {
            m/
            $test_dir\ .*_u:.*_r:$fcontext_type1:s0.*
            $test_dir\/$test_file\ .*_u:.*_r:$fcontext_type2:s0/sx
        });

    # check SELinux contexts of test dir and file
    $self->check_fcontext("$test_dir",                "$fcontext_type_default");
    $self->check_fcontext("${test_dir}/${test_file}", "$fcontext_type_default");

    # restorecon
    assert_script_run("restorecon ${test_dir}/");
    assert_script_run("restorecon ${test_dir}/${test_file}");

    # check SELinux contexts of test dir and file
    $self->check_fcontext("$test_dir",                "$fcontext_type1");
    $self->check_fcontext("${test_dir}/${test_file}", "$fcontext_type2");

    # test option "-m": modify local customizations
    assert_script_run("semanage fcontext -m -t $fcontext_type3 ${test_dir}/${test_file}");
    # check contexts file
    validate_script_output(
        "cat $file_contexts_local",
        sub {
            m/
            $test_dir\ .*_u:.*_r:$fcontext_type1:s0.*
            $test_dir\/$test_file\ .*_u:.*_r:$fcontext_type3:s0/sx
        });

    # restorecon
    assert_script_run("restorecon ${test_dir}/${test_file}");

    # check SELinux contexts of test file
    $self->check_fcontext("${test_dir}/${test_file}", "$fcontext_type3");

    # clean up and test option "-D": remove all local customizations
    assert_script_run("semanage fcontext -D");
    # check file contents for double confirmation
    assert_script_run("cat $file_contexts_local");
    my $script_output = script_output("grep -v '^#' $file_contexts_local | grep -v '^\$'", proceed_on_failure => 1);
    if ($script_output) {
        record_info("ERROR", "$file_contexts_local is not clean, still has records: $script_output", result => "fail");
        $self->result("fail");
    }
}

1;
