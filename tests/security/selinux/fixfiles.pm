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
# Summary: Test "fixfiles" can fix file SELinux security contexts
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#65672, tc#1745370

use base "selinuxtest";
use power_action_utils "power_action";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;
    my $file_output = $selinuxtest::file_output;

    select_console "root-console";

    # test `fixfiles check` can print any incorrect file context labels
    assert_script_run("fixfiles check > $file_output 2>&1", timeout => 300);

    # pick up a test file to test
    my $file_info     = script_output("grep -i 'Would relabel' $file_output | tail -1");
    my $file_name     = script_output("echo $file_info | cut -d ' ' -f3");
    my $fcontext_pre  = script_output("echo $file_info | cut -d ' ' -f5");
    my $fcontext_post = script_output("echo $file_info | cut -d ' ' -f7");

    # test `fixfiles restore`: run fixfiles restore on the test file and check the results
    $self->fixfiles_restore("$file_name", "$fcontext_pre", "$fcontext_post");

    # test `fixfiles verify/check`: to double confirm, there should be nothing to do with $file_name
    my $script_output = script_output("fixfiles verify $file_name", proceed_on_failure => 1);
    if ($script_output) {
        record_info("ERROR", "verify $file_name, it is not well restored: $script_output", result => "fail");
        $self->result("fail");
    }
    $script_output = script_output("fixfiles check $file_name", proceed_on_failure => 1);
    if ($script_output) {
        record_info("ERROR", "check $file_name, it is not well restored: $script_output", result => "fail");
        $self->result("fail");
    }
}

1;
