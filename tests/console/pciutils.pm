#SUSE"s openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: pciutils
# Summary: PED-8229, Introduce smoke tests for PCI Utils
# Maintainer: QE-Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_sle';
use registration 'add_suseconnect_product';

sub run {
    select_serial_terminal;

    add_suseconnect_product('sle-module-development-tools') if (is_sle('>=15') && is_sle('<16'));
    zypper_call('in cpupower powertop pciutils');
    record_info('pciutis version:', script_output('rpm -q pciutils'));

    # Run basic powertop, sysinfo and cpupower tests
    assert_script_run('powertop -r /tmp/powertop_report');
    assert_script_run('cpupower frequency-info');
}

1;
