# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: use 389ds client to connect with server before
#          and after migration
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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

    mutex_create("FINISH_STEP1");

    mutex_wait("389DS_READY_2");
    services::389ds_sssd::check_service();
}

sub post_fail_hook {
    upload_logs("/var/log/messages");
    upload_logs("/etc/sssd/sssd.conf");
}

1;
