# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run integration_services_check
# Maintainer: Michal Nowak <mnowak@suse.com>

use base 'consoletest';
use testapi;
use utils 'integration_services_check';

sub run {
    select_console 'root-console';

    integration_services_check();
}

1;
