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
use testapi qw(select_console enter_cmd wait_still_screen save_screenshot get_var);

sub run {
    my $podman_cmd = "podman container runlabel run registry.opensuse.org/suse/alp/workloads/tumbleweed_containerfiles/suse/alp/workloads/yast-mgmt-ncurses-test-api";
    select_console('root-console');
    enter_cmd(get_var('YUI_PARAMS') . " $podman_cmd");
    my $control_center = $testapi::distri->get_control_center();
    my $release_notes = $testapi::distri->get_release_notes();
    $control_center->open_release_notes();
    save_screenshot();
    $release_notes->close();
    save_screenshot();
    $control_center->quit();
}

1;
