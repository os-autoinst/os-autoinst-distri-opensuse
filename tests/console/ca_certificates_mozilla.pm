# SUSE's openQA tests
#
# Copyright 2018-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ca-certificates-mozilla openssl
# Summary: Install ca-certificates-mozilla and test connection to a secure website
# - install ca-certificates-mozilla and openssl
# - connect to static.opensuse.org:443 using openssl and verify that the return code is 0
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';

sub run {
    select_serial_terminal;
    zypper_call 'in ca-certificates-mozilla openssl';
    my $server = "static.opensuse.org";    # due to infra setup, need to pass explicit servername for older openssl
    assert_script_run(qq[echo "x" | openssl s_client -connect $server:443 -servername $server | grep "Verify return code: 0"]);
}

1;
