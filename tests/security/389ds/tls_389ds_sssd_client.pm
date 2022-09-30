# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Implement & Integrate 389ds + sssd test case into openQA,
#          This test module covers the sssd client tests
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#88513, poo#92410, poo#101698, poo#101800, tc#1768672

use base 'consoletest';
use testapi;
use strict;
use warnings;
use utils;
use lockapi;
use services::389ds_sssd_client;

sub run {
    select_console("root-console");

    services::389ds_sssd::install_service();

    mutex_wait("389DS_READY");

    services::389ds_sssd::config_service();
    services::389ds_sssd::start_service();
    services::389ds_sssd::enable_service();
    services::389ds_sssd::check_service();
}

sub post_fail_hook {
    upload_logs("/var/log/messages");
    upload_logs("/etc/sssd/sssd.conf");
}

1;
