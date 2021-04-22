# SUSE's openQA tests
#
# Copyright © 2016-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test rollback after migration back to downgraded system
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use migration 'check_rollback_system';
use power_action_utils 'power_action';
use Utils::Backends 'is_pvm';
use version_utils;

sub run {
    my ($self) = @_;
    if (is_leap_migration && check_var('DESKTOP', 'gnome')) {
        assert_screen 'generic-desktop', 90;
    }
    else {
        assert_screen [qw(linux-login displaymanager)], 300;
    }
    select_console 'root-console';
    # 1)
    script_run('touch NOWRITE;test ! -f NOWRITE', 0);
    # 1b) just debugging infos
    script_run("snapper list",        0);
    script_run("cat /etc/os-release", 0);
    # rollback
    script_run("snapper rollback -d rollback-before-migration");
    my $ret     = script_run("snapper --help | grep disable-used-space");
    my $disable = '';
    $disable = '--disable-used-space' unless $ret;
    assert_script_run("snapper list $disable | tail -n 2 | grep rollback", 180);
    power_action('reboot', textmode => 1, keepconsole => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(ready_time => 300, bootloader_time => 300);
    select_console 'root-console';
    check_rollback_system;
}

sub test_flags {
    return {fatal => 1};

}

1;
