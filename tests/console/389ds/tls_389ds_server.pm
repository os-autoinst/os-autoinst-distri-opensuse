# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Implement & Integrate 389ds + sssd test case into openQA,
#          This test module covers the server features check before
#          and after migration, 389ds exists sles15sp3+
#
# Maintainer: Yutao Wang<yuwang@suse.com>

use base 'consoletest';
use testapi;
use strict;
use warnings;
use utils;
use lockapi;
use mmapi;
use services::389ds_server;

sub run {
    select_console("root-console");

    if (check_var('VERSION', get_required_var('ORIGIN_SYSTEM_VERSION'))) {
        services::389ds_server::install_service();
        services::389ds_server::config_service();
        services::389ds_server::enable_service();
        services::389ds_server::check_service();

        # Add lock for client
        mutex_create("389DS_READY");

        # Finish job
        my $children = get_children();
        mutex_wait("FINISH_STEP1", (keys %$children)[0]);
    }
    if (check_var('VERSION', get_required_var('UPGRADE_TARGET_VERSION'))) {
        validate_script_output("dsctl localhost status", sub { m/Instance.*is running/ });

        mutex_create("389DS_READY_2");

        # Finish job
        wait_for_children;
    }
}

1;
