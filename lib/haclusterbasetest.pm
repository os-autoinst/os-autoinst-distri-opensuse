# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Base class for HA Cluster tests

package haclusterbasetest;

use Mojo::Base 'opensusebasetest';
use strict;
use warnings;
use utils;
use testapi;
use isotovideo;
use hacluster qw(ha_export_logs);
use Utils::Logging qw(export_logs);
use version_utils 'is_sle';
use x11utils qw(ensure_unlocked_desktop);

=head1 SYNOPSIS

Base class for HA Cluster tests.
=cut

our $prev_console;

=head2 pre_run_hook

    pre_run_hook()

This is one of the test module interfaces C<'pre_run_hook()'>.
It sets C<'$prev_console'> before running test steps.
=cut

sub pre_run_hook {
    my ($self) = @_;
    # perl -c will give a "only used once" message
    # here and this makes the travis ci tests fail.
    1 if defined $testapi::selected_console;
    $prev_console = $testapi::selected_console;
    record_info(__PACKAGE__ . ':' . 'pre_run_hook' . ' ' . "prev_console=$prev_console");
}

=head2 post_run_hook

    post_run_hook()

This is one of the test module interfaces C<'post_run_hook()'>.
It restores/unlocks C<'$prev_console'>, clear the console and ensure that it really got cleareafter.
=cut

sub post_run_hook {
    my ($self) = @_;
    record_info(__PACKAGE__ . ':' . 'post_run_hook' . ' ' . "prev_console=$prev_console");

    return unless ($prev_console);
    select_console($prev_console, await_console => 0);
    if ($prev_console eq 'x11') {
        ensure_unlocked_desktop;
    }
    else {
        $self->clear_and_verify_console;
    }
}

=head2 post_fail_hook

    post_fail_hook()

This is one of the test module interfaces C<'post_fail_hook()'>.
It saves a screenshot and logs.
=cut

sub post_fail_hook {
    my ($self) = @_;
    record_info(__PACKAGE__ . ':' . 'post_fail_hook');

    # Save a screenshot before trying further measures which might fail
    save_screenshot;

    # Try to save logs as a last resort
    ha_export_logs;
    export_logs;
}

=head2 test_flags

    test_flags()

This is one of the test module interfaces C<'test_flags()'>.

=over

=item

Specify what should happen when test execution of the current test module is finished depending on the result.

=item

Set C<'milestone=1'>: after this test succeeds, update the 'lastgood' snapshot of the SUT

=item

Set C<'fatal=1'>: when set to 1 the whole test suite is aborted if the test module fails. The overall state is set to failed.

=back
=cut

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
