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
# Summary: Test "# restorecon" to do file system labeling
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#65672, tc#1741291

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

    # label system: testing "-R / -P / -V"
    script_run("restorecon -Rp /",  600);
    script_run("restorecon -Rp /*", 600);
    script_run("restorecon -Rv /",  600);
    script_run("restorecon -Rv /*", 600);

    # clean up in case: remove all local customizations
    assert_script_run("semanage fcontext -D");

    # add local customizations
    assert_script_run("semanage fcontext -a -t $fcontext_type1 $test_dir");
    assert_script_run("semanage fcontext -a -t $fcontext_type2 ${test_dir}/${test_file}");

    # run "# restorecon -R" to label test dir/file
    assert_script_run("restorecon -R $test_dir");
    assert_script_run("restorecon -R $test_dir/*");
    validate_script_output("ls -Zd $test_dir",               sub { m/$fcontext_type1/ });
    validate_script_output("ls -Z ${test_dir}/${test_file}", sub { m/$fcontext_type2/ });

    # clean up: remove all local customizations
    assert_script_run("semanage fcontext -D");
}

1;
