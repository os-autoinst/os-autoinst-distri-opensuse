# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Add an addon to SLES via SCC using YaST module in ncurses
# Maintainer: QA SLE YaST <qa-sle-yast@suse.com>

use base 'y2_module_consoletest';
use strict;
use warnings;
use testapi;
use registration;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    select_console('root-console');
    # Clean up registration in case system was previously registered
    cleanup_registration if is_sle('>=15');
    yast_scc_registration(yast2_opts => '--ncurses');
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    verify_scc;
    investigate_log_empty_license;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
