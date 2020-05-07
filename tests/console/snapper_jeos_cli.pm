# SUSE's openQA tests
#
# Copyright © 2018-2020 SUSE LLC
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
use warnings;
use power_action_utils qw(power_action);
use version_utils qw(is_sle);

sub rollback_and_reboot {
    my ($self, $rollback_id) = @_;
    assert_script_run("snapper rollback $rollback_id");
    assert_script_run("snapper list");
    power_action('reboot');
    $self->wait_boot;
    select_console('root-console');
    assert_script_run("snapper list");
}

sub run {
    my ($self) = @_;

    select_console('root-console');
    my $file       = '/etc/openQA_snapper_test';
    my $openqainit = script_output("snapper create -p -d openqainit");
    assert_script_run("touch $file");
    my $openqalatest = script_output("snapper create -p -d openqalatest");
    assert_script_run("snapper list");

    $self->rollback_and_reboot($openqainit);
    assert_script_run("! ls -l $file");

    $self->rollback_and_reboot($openqalatest);
    assert_script_run("ls -l $file");
    assert_script_run("rm -v $file");

    $self->rollback_and_reboot($openqainit);
    assert_script_run("! ls -l $file");

}

1;
