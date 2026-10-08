# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run integration_services_check
# Maintainer: Michal Nowak <mnowak@suse.com>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_text_console';
use utils 'integration_services_check';

sub run {
    select_text_console;

    integration_services_check();
}

1;
