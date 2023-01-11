# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Ensure the service inactive & enabled after set on tree-based interface for yast2 dns-server
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi qw(save_screenshot select_console);
use utils;

sub run {
    my $dns_server = $testapi::distri->get_dns_server();

    select_console 'root-console';
    YaST::Module::open(module => 'dns-server', ui => 'ncurses');

    $dns_server->process_reading_configuration();
    $dns_server->select_stop_after_writing_configuration();
    save_screenshot;
    $dns_server->select_start_on_boot_after_reboot();
    save_screenshot;
    $dns_server->accept_apply();
    save_screenshot;
    $dns_server->accept_ok();

    select_console 'root-console';
    systemctl 'is-active named', expect_false => 1;
    systemctl 'is-enabled named', expect_false => 0;
}

1;
