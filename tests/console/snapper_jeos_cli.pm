# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Snapshot creation and rollback on JeOS
# Maintainer: Ciprian Cret <ccret@suse.com>

use base 'consoletest';
use testapi;
use utils;
use strict;
use power_action_utils 'power_action';
use version_utils 'is_sle';

sub run {
    my ($self) = @_;

    select_console('root-console');
    my $file       = '/etc/openQA_snapper_test';
    my $openqainit = 'openqainit';
    assert_script_run("snapper create -d $openqainit");
    assert_script_run("touch $file");
    my $openqalatest = 'openqalatest';
    assert_script_run("snapper create -d $openqalatest");
    assert_script_run("snapper list");
    my $snap_id             = is_sle('15+') ? "'{ print \$1 }'" : "'{ print \$3 }'";
    my $openqainit_snapshot = script_output("snapper list | grep -w $openqainit | awk $snap_id | tr -d '\\n'");
    my $latest_snapshot     = script_output("snapper list | grep -w $openqalatest | awk $snap_id | tr -d '\\n'");
    my $init_snapshot       = script_output("snapper list | grep 'single.*$openqainit' | awk $snap_id | tr -d '\\n'");
    my $openqarollback      = 'openqarollback';
    assert_script_run("snapper rollback -d $openqarollback $init_snapshot");
    assert_script_run("snapper list");
    power_action('reboot');
    $self->wait_boot;

    select_console('root-console');
    assert_script_run("snapper list");
    assert_script_run("! ls -l $file");
    assert_script_run("snapper rollback $latest_snapshot");
    assert_script_run("snapper list");
    power_action('reboot');
    $self->wait_boot;

    select_console('root-console');
    assert_script_run("snapper list");
    assert_script_run("ls -l $file");
    assert_script_run("rm -v $file");
    assert_script_run("snapper rollback $openqainit_snapshot");
    assert_script_run("snapper list");
    power_action('reboot');
    $self->wait_boot;

    select_console('root-console');
    assert_script_run("snapper list");
    assert_script_run("! ls -l $file");
}

1;
