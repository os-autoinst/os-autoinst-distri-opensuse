# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "fixfiles" can fix file SELinux security contexts
# Maintainer: QE Security <none@suse.de>
# Tags: poo#65672, tc#1745370

use base "selinuxtest";
use power_action_utils "power_action";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_alp);

sub run {
    my ($self) = shift;
    my $file_output = $selinuxtest::file_output;

    select_serial_terminal;

    # test `fixfiles check` can print any incorrect file context labels
    assert_script_run("fixfiles check > $file_output 2>&1", timeout => 300);

    # pick up a test file to test
    my $file_info = script_output("grep -i 'Would relabel' $file_output | tail -1");
    my $file_name = script_output("echo $file_info | cut -d ' ' -f3");
    my $fcontext_pre = script_output("echo $file_info | cut -d ' ' -f5");
    my $fcontext_post = script_output("echo $file_info | cut -d ' ' -f7");

    # test `fixfiles restore`: run fixfiles restore on the test file and check the results
    $self->fixfiles_restore("$file_name", "$fcontext_pre", "$fcontext_post");

    # test `fixfiles verify/check`: to double confirm, there should be nothing to do with $file_name
    my $script_output = script_output("fixfiles verify $file_name", proceed_on_failure => 1);
    # On ALP, there is always a note about excluded fixfiles directory overlay
    if (is_alp) {
        $script_output =~ s/skipping the directory \/var\/lib\/overlay//;
    }
    if ($script_output) {
        record_info("ERROR", "verify $file_name, it is not well restored: $script_output", result => "fail");
        $self->result("fail");
    }
    $script_output = script_output("fixfiles check $file_name", proceed_on_failure => 1);
    if (is_alp) {
        $script_output =~ s/skipping the directory \/var\/lib\/overlay//;
    }
    if ($script_output) {
        record_info("ERROR", "check $file_name, it is not well restored: $script_output", result => "fail");
        $self->result("fail");
    }
}

1;
