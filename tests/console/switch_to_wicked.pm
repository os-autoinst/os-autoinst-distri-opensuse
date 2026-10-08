# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Switch from NetworkManager to wicked.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use y2_module_basetest;
use testapi;
use serial_terminal 'select_text_console';
use mm_network;

sub run {
    my ($self) = shift;
    return unless is_network_manager_default;
    ensure_installed 'wicked';
    select_text_console;
    $self->use_wicked_network_manager;
    configure_dhcp;
}

1;
