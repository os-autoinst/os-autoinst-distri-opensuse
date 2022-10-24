# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: OpenSSL update regression test using NodeJS tls and crypto tests
#          The test will:
#          - Check the latest nodejs package and sources available and install it
#          - Apply patches to the sources
#          - Run the crypto and tls tests.
#          - List eventually skipped and failed test
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use repo_tools 'generate_version';

sub run {
    #Preparation
    select_serial_terminal;

    my $os_version = generate_version();
    assert_script_run 'wget --quiet ' . data_url('console/test_openssl_nodejs.sh');
    assert_script_run 'chmod +x test_openssl_nodejs.sh';
    assert_script_run "./test_openssl_nodejs.sh $os_version", 900;
}

1;
