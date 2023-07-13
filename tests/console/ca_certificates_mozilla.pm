# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ca-certificates-mozilla openssl
# Summary: Install ca-certificates-mozilla and test connection to a secure website
# - install ca-certificates-mozilla and openssl
# - connect to static.opensuse.org:443 using openssl and verify that the return code is 0
# Maintainer: Orestis Nalmpantis <onalmpantis@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';

sub run {
    select_serial_terminal;
    zypper_call 'in ca-certificates-mozilla openssl';
    assert_script_run('echo "x" | openssl s_client -connect static.opensuse.org:443 | grep "Verify return code: 0"');
}

1;
