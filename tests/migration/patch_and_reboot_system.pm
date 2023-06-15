# SLE15 migration tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Fully patch the system before conducting migration and then reboot
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_desktop_installed is_upgrade);
use migration;

sub run {
    select_console 'root-console';

    my ($self) = @_;

    fully_patch_system();
    enter_cmd "reboot";
    $self->wait_boot(textmode => !is_desktop_installed(), ready_time => 600, bootloader_time => 300);
    select_console 'root-console';
}

1;
