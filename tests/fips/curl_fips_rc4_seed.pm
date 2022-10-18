# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: curl libcurl4
# Summary: Test curl RC4 and SEED ciphers with fips enabled
#    This is new curl test case for fips related.
#    Both RC4 and SEED are not approved cipher by FIPS140-2.
#    In a fips enabled system, it will get a failed result if run curl command
#    with RC4 and SEED ciphers.
# Maintainer: QE Security <none@suse.de>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;

sub run {
    my $self = shift;
    select_serial_terminal;
    validate_script_output "curl --ciphers RC4,SEED -v https://eu.httpbin.org/get 2>&1 || true", sub { m/failed setting cipher/ };
    validate_script_output "rpm -q curl libcurl4", sub { m/curl-.*/ };
}

1;
