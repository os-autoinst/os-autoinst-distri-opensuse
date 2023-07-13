# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: openssl
# Summary: openssl 1.1.1 supports and negotiates by default the new TLS 1.3 protocol.
#          Applications that leave everything to the openssl library will automatically
#          start to negotiate the TLS 1.3 protocol. However, many packages have their
#          own settings which override the library defaults and these either have to be
#          recompiled against openssl 1.1.1 or might even need extra patching.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64992, tc#1744100

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use apachetest;

sub run {
    select_serial_terminal;
    setup_apache2(mode => 'SSL');

    # List the supported ciphers and make sure TLSV1.3 is there
    validate_script_output 'openssl ciphers -v', sub { m/TLSv1\.3.*/xg };

    # Establish a transparent connection to apache server to check the TLS protocol
    validate_script_output 'echo | openssl s_client -connect localhost:443 2>&1', sub { m/TLSv1\.3.*/xg };

    # Transfer a URL to check the TLS protocol
    validate_script_output 'curl -Ivvv  https://www.google.com 2>&1', sub { m/TLSv1\.3.*/xg };
}

1;
