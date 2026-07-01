# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "fixfiles" can fix file SELinux security contexts
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'selinuxtest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self) = shift;

    select_serial_terminal;

    my $test_file = '/root/selinux_fixfiles_test';

    # Create the test file directly in its final location so SELinux assigns
    # the policy-correct context for /root immediately on creation.
    assert_script_run("touch $test_file");

    # Capture the correct context empirically; this is the ground truth the
    # policy assigns to files in /root, whatever type name the active policy uses.
    my $fcontext_post = script_output("stat -c %C $test_file");
    my ($type_post) = $fcontext_post =~ m{:([^:]+):};
    record_info('Correct context', "Policy-correct context for $test_file: $fcontext_post");

    # Deliberately mislabel the file with a wrong type using chcon.
    # tmp_t is a well-known type that is never correct for files in /root.
    my $type_pre = 'tmp_t';
    assert_script_run("chcon -t $type_pre $test_file");
    record_info('Mislabeled', "Deliberately applied wrong SELinux type '$type_pre' to $test_file");

    # Sanity check: confirm the file now carries the wrong context.
    validate_script_output("stat -c %C $test_file", sub { m/:$type_pre:/ });

    # Test `fixfiles restore`: relabel the file and verify the context transition
    record_info('fixfiles restore', "Restoring context of $test_file from '$type_pre' to '$type_post'");
    $self->fixfiles_restore($test_file, $type_pre, $type_post);

    # Test `fixfiles verify/check`: confirm the file is no longer reported as mislabeled
    for my $task (qw(verify check)) {
        my $script_output = script_output("fixfiles $task $test_file", proceed_on_failure => 1);
        record_info("fixfiles $task", $script_output || 'No mislabeled files reported');
        die "fixfiles $task still reports $test_file as mislabeled: $script_output"
          if ($script_output =~ m/\Q$test_file\E/);
    }

    assert_script_run("rm $test_file");
}

1;
