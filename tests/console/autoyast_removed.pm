# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Confirm autoyast has been removed from installation overview
# - Check if autoinst.xml does not exist anymore on /root "[ ! -f /root/autoinst.xml ]"
# Maintainer: mkravec <mkravec@suse.com>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_text_console';

# poo#11442
sub run {
    select_text_console;
    assert_script_run("[ ! -f /root/autoinst.xml ]");
}

1;
