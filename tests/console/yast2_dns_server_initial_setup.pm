# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Ensure the service active & enabled after set on wizard-like interface for yast2 dns-server
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi qw(save_screenshot select_console);
use utils;

sub run {
    my $dns_server_setup = $testapi::distri->get_dns_server_setup();

    select_console 'root-console';
    zypper_call 'in yast2-dns-server bind';
    YaST::Module::open(module => 'dns-server', ui => 'ncurses');

    $dns_server_setup->process_reading_configuration();
    save_screenshot;
    $dns_server_setup->accept_forwarder_settings();
    save_screenshot;
    $dns_server_setup->accept_dns_zones();
    save_screenshot;
    $dns_server_setup->select_start_after_writing_configuration();
    save_screenshot;
    $dns_server_setup->select_start_on_boot_after_reboot();
    save_screenshot;
    $dns_server_setup->finish_setup();

    select_console 'root-console';
    systemctl 'is-active named';
    systemctl 'is-enabled named';
}

1;
