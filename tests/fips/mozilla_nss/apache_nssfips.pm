# SUSE's Apache+NSSFips tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable NSS module for Apache2 server with NSSFips on
# Maintainer: QE Security <none@suse.de>

# Tags: poo#207477

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use apachetest;
use version_utils 'is_sle';

sub run {
    select_serial_terminal;
    if (is_sle('>=16.0')) {
        record_info('TEST SKIPPED', "apache2-mod_nss package not present in SLE16");
        return;
    }
    setup_apache2(mode => 'NSSFIPS');
}

1;
