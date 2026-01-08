# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-snapper snapper
# Summary: yast2 snapper test for ncurses
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base qw(y2snapper_common y2_module_consoletest);

use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console 'root-console';
    zypper_call('in yast2-snapper');

    $self->y2snapper_adding_new_snapper_conf;
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'snapper');

    $self->y2snapper_new_snapshot(1);
    wait_serial("$module_name-0") || die "yast2 snapper failed";

    $self->y2snapper_apply_filesystem_changes;

    $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'snapper');
    $self->y2snapper_show_changes_and_delete(1);
    $self->y2snapper_clean_and_quit($module_name, 1);
}

sub post_fail_hook {
    my ($self) = @_;
    $self->y2snapper_failure_analysis;
}

1;
