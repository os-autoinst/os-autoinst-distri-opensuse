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

our $prev_console;

sub pre_run_hook {
    my ($self) = @_;
    # perl -c will give a "only used once" message
    # here and this makes the travis ci tests fail.
    1 if defined $testapi::selected_console;
    $prev_console = $testapi::selected_console;
    record_info(__PACKAGE__ . ':' . 'pre_run_hook' . ' ' . "prev_console=$prev_console");
}

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

sub post_fail_hook {
    my ($self) = @_;
    record_info(__PACKAGE__ . ':' . 'post_fail_hook');

    # Save a screenshot before trying further measures which might fail
    save_screenshot;

    # Try to save logs as a last resort
    ha_export_logs;
    export_logs;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
