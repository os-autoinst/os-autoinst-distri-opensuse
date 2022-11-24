# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Unified dependency issues resolver
# - If manual intervention is needed during software selection on installation:
#   - If WORKAROUND_DEPS is set, try to use first suggestion to fix dependency issue
#   - If BREAK_DEPS is set, choose option to break dependencies
# - Handle license, automatic changes, unsupported packages, errors with
# patterns.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base "y2_installbase";
use strict;
use warnings;
use testapi;
use Utils::Logging 'upload_solvertestcase_logs';

sub run {
    my ($self) = @_;
    assert_screen('installation-settings-overview-loaded', 420);

    if (check_screen('manual-intervention', 0)) {
        $self->deal_with_dependency_issues;
    } elsif (check_screen('installation-settings-overview-loaded-scrollbar')) {
        # We still need further check if we find scrollbar
        assert_and_click "installation-settings-overview-loaded-scrollbar-down";
        if (check_screen('manual-intervention', 0)) {
            $self->deal_with_dependency_issues;
        }
    }
}

sub post_fail_hook {
    my $self = shift;
    select_console 'root-console';
    upload_solvertestcase_logs();
    # workaround to get the y2logs.tar.bz2 at early stage
    script_run "save_y2logs /tmp/y2logs.tar.bz2";
    upload_logs "/tmp/y2logs.tar.bz2";
    set_var('Y2LOGS_UPLOADED', 1);
    $self->SUPER::post_fail_hook;
}

1;
