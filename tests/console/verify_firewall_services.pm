# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: Verification of firewall being inactive and allowing services http https.
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use parent 'y2_module_consoletest';
use testapi;
use utils;

sub run {
    systemctl 'is-active firewalld', expect_false => 1;
    validate_script_output("firewall-offline-cmd --zone=external --list-services", sub { /http https/ });

}

1;
