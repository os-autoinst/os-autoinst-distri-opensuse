# SUSE's openQA tests
#
# Copyright (c) 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: yast2 snapper test for ncurses
# Maintainer: Wei Jiang <wjiang@suse.com>

use base qw(y2snapper_common console_yasttest);
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console 'root-console';
    zypper_call('in yast2-snapper');

    my $module_name = y2logsstep::yast2_console_exec(yast2_module => 'snapper');

    $self->y2snapper_new_snapshot(1);
    wait_serial("$module_name-0") || die "yast2 snapper failed";

    $self->y2snapper_untar_testfile;

    $module_name = y2logsstep::yast2_console_exec(yast2_module => 'snapper');
    $self->y2snapper_show_changes_and_delete(1);
    $self->y2snapper_clean_and_quit($module_name);
}

sub post_fail_hook {
    my ($self) = @_;
    $self->y2snapper_failure_analysis;
}

1;
