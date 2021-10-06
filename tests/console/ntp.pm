# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ntp
# Summary: Basics ntp test - add ntp servers, obtain time
# Maintainer: Katerina Lorenzova <klorenzova@suse.cz>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use services::ntpd;

sub run {
    select_console 'root-console';
    services::ntpd::install_service();
    services::ntpd::enable_service();
    services::ntpd::start_service();
    services::ntpd::check_config();
    services::ntpd::config_service();
    services::ntpd::check_service();
    services::ntpd::check_function();
}

1;
