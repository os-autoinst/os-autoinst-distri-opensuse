# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Verification of firewall being inactive and allowing services http https.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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
