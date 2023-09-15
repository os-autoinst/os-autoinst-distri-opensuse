# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Start containerized YaST Control Center with ncurses
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use y2_module_consoletest;
use testapi qw(select_console wait_serial save_screenshot get_var);

sub run {
    select_console('root-console');

    my $podman_cmd = " podman container runlabel run registry.opensuse.org/suse/alp/workloads/tumbleweed_containerfiles/suse/alp/workloads/yast-mgmt-ncurses-test-api;";
    my $module_name = y2_module_consoletest::yast2_console_exec(extra_vars => get_var('YUI_PARAMS'), podman => $podman_cmd);
    my $control_center = $testapi::distri->get_control_center();
    my $release_notes = $testapi::distri->get_release_notes();
    $control_center->open_release_notes();
    save_screenshot();
    $release_notes->close();
    save_screenshot();
    $control_center->quit();
    wait_serial("$module_name-0", timeout => 60) ||
      die "Fail! $podman_cmd is not closed or non-zero code returned.";
}

1;
