# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run integration_services_check
# Maintainer: Michal Nowak <mnowak@suse.com>

use base 'consoletest';
use testapi;
use utils 'integration_services_check';
use strict;
use warnings;

sub run {
    select_console 'root-console';

    integration_services_check;
}

1;
