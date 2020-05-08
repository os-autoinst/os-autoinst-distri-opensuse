# Copyright (C) 2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Base module for SELinux test cases
# Maintainer: llzhao <llzhao@suse.com>

package selinuxtest;

use strict;
use warnings;
use testapi;
use utils;

use base "opensusebasetest";

our @EXPORT = qw(
  $file_contexts_local
  $file_output
);

our $file_contexts_local = "/etc/selinux/minimum/contexts/files/file_contexts.local";
our $file_output         = "/tmp/cmd_output";

# creat a test dir/file
sub create_test_file {
    my ($self, $test_dir, $test_file) = @_;

    assert_script_run("rm -rf $test_dir");
    assert_script_run("mkdir -p $test_dir");
    assert_script_run("touch ${test_dir}/${test_file}");
}

# run `fixfiles restore` and check the fcontext before and after
sub fixfiles_restore {
    my ($self, $file_name, $fcontext_pre, $fcontext_post) = @_;

    if (script_run("[ -z $file_name ]") == 0) {
        record_info("WARNING", "no file need to be restored", result => "softfail");
    }
    elsif (script_run("[ -f $file_name ]") == 0) {
        validate_script_output("ls -Z $file_name", sub { m/$fcontext_pre/ });
        assert_script_run("fixfiles restore $file_name");
        validate_script_output("ls -Z $file_name", sub { m/$fcontext_post/ });
    }
    elsif (script_run("[ -d $file_name ]") == 0) {
        validate_script_output("ls -Zd $file_name", sub { m/$fcontext_pre/ });
        assert_script_run("fixfiles restore $file_name");
        validate_script_output("ls -Zd $file_name", sub { m/$fcontext_post/ });
    }
}

# check SELinux contexts of a file/dir
sub check_fcontext {
    my ($self, $file_name, $fcontext) = @_;

    if (script_run("[ -f $file_name ]") == 0) {
        validate_script_output("ls -Z $file_name", sub { m/.*_u:.*_r:$fcontext:s0\ .*$file_name$/ });
    }
    elsif (script_run("[ -d $file_name ]") == 0) {
        validate_script_output("ls -Zd $file_name", sub { m/.*_u:.*_r:$fcontext:s0\ .*$file_name$/ });
    }
    else {
        record_info("WARNING", "file \"$file_name\" is abnormal", result => "softfail");
        assert_script_run("ls -lZd $file_name");
    }
}

# check SELinux security category of a file/dir
sub check_category {
    my ($self, $file_name, $category) = @_;

    if (script_run("[ -f $file_name ]") == 0) {
        validate_script_output("ls -Z $file_name", sub { m/.*_u:.*_r:.*_t:$category\ .*$file_name$/ });
    }
    elsif (script_run("[ -d $file_name ]") == 0) {
        validate_script_output("ls -Zd $file_name", sub { m/.*_u:.*_r:.*_t:$category\ .*$file_name$/ });
    }
    else {
        record_info("WARNING", "file \"$file_name\" is abnormal", result => "softfail");
        assert_script_run("ls -lZd $file_name");
    }
}

1;
