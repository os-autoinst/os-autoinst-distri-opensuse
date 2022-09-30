# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Implement & Integrate 389ds + sssd test case into openQA,
#          This test module covers the server setup processes
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#88513, poo#92410, poo#93832, poo#101698, poo#101800, tc#1768672

use base 'consoletest';
use testapi;
use strict;
use warnings;
use utils;
use lockapi;
use mmapi 'wait_for_children';
use services::389ds_server;

sub run {
    select_console("root-console");

    services::389ds_server::install_service();
    services::389ds_server::config_service();
    services::389ds_server::enable_service();
    services::389ds_server::check_service();

    # Add lock for client
    mutex_create("389DS_READY");

    # Finish job
    wait_for_children;
}

1;
