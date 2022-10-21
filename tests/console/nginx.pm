# SUSE's Apache+SSL tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test nginx service, http, https and http2 capabilities
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use services::nginx;
use utils 'clear_console';

sub run {
    select_serial_terminal;

    services::nginx::install_service();
    services::nginx::enable_service();
    services::nginx::start_service();
    services::nginx::check_service();
    services::nginx::config_service();
    services::nginx::check_function();
}

sub test_flags {
    return {fatal => 0};
}

1;
