# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: fio oprofile psmisc
# Summary: Simple tests for oprofile.
# - profile example application (fio to create some load)
# - check report
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>

use strict;
use warnings;
use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product);


sub run {
    select_serial_terminal;

    # Add required product
    if (is_sle '>=15') {
        add_suseconnect_product('sle-module-development-tools');
    } else {
        add_suseconnect_product('sle-sdk');
    }

    # Install fio as load generator and oprofile
    zypper_call "in fio oprofile psmisc";

    # Start a system wide profiling
    script_run "(operf --system-wide &)";

    # Start load and stop profiler when finished
    assert_script_run "fio --name=randwrite --filename=/tmp/randwrite --bs=4k --size=1G; killall -s SIGINT operf";

    # Make sure the report is generated correctly and also check for an entry for the fio load
    assert_script_run "opreport > /tmp/opreport.log";
    upload_logs "/tmp/opreport.log";
    assert_script_run "opreport | grep 'fio'";
}

sub post_run_hook {
    script_run "rm -rf /tmp/randwrite /tmp/opreport.log oprofile_data";
}

1;
