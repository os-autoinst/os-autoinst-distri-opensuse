# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "fixfiles" can fix file SELinux security contexts
# Maintainer: QE Security <none@suse.de>

use base "selinuxtest";
use power_action_utils "power_action";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self) = shift;
    my $file_output = $selinuxtest::file_output;

    select_serial_terminal;

    # `fixfiles check` prints any incorrect file context labels
    assert_script_run("fixfiles check > $file_output 2>&1", timeout => 300);

    # pick up a sample file to check the 'restore' feature
    my $last_line = script_output("grep -i 'Would relabel' $file_output | tail -1");
    my ($file_name, $fcontext_pre, $fcontext_post) = $last_line =~ m{^Would relabel\s+(.+?)\s+from\s+(\S+)\s+to\s+(\S+)$};

    # test `fixfiles restore`: run fixfiles restore on the test file and check the results
    $self->fixfiles_restore($file_name, $fcontext_pre, $fcontext_post);

    # test `fixfiles verify/check`: to double confirm, there should be nothing to do with $file_name
    for my $task (qw(verify check)) {
        my $script_output = script_output("fixfiles $task $file_name", proceed_on_failure => 1);
        die "$task $file_name, it is not well restored: $script_output" if ($script_output =~ m/$file_name/);
    }
    # cleanup
    assert_script_run "rm -f $file_output";
}

1;
