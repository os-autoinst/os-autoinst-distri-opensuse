# SUSE's openQA tests - FIPS tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: greenbone-security-assistant
# Summary: Case 1525263 - Verify libmicrohttpd via Greenbone Security Assistant
# Maintainer: QE Security <none@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    # Install greenbone-security-assistant
    zypper_call("--no-gpg-checks in greenbone-security-assistant");

    # Create self-signed certificates
    clear_console;
    assert_script_run "mkdir -p /etc/openvas/cert";
    assert_script_run "cd /etc/openvas/cert";
    assert_script_run "echo -e \"\n\n\n\n\n\n\" | openssl req -new -x509 -newkey rsa:2048 -keyout gsa.key -days 3560 -out gsa.cert -nodes";
    assert_script_run "ls gsa.key gsa.cert";

    # Start greenbone-security-assistant
    clear_console;
    assert_script_run
"/usr/sbin/gsad --listen=127.0.0.1 --port=9392 --alisten=127.0.0.1 --aport=9393 --mlisten=127.0.0.1 --import=9390 --ssl-private-key=/etc/openvas/cert/gsa.key --ssl-certificate=/etc/openvas/cert/gsa.cert &> gsad.log";
    upload_logs "/etc/openvas/cert/gsad.log";

    # Check login page of Greenbone Security Assistant Web
    validate_script_output "curl -k https://localhost:9392/login/login.html", sub { m/Greenbone Security Assistant/ };

    # Stop greenbone-security-assistant
    assert_script_run "killall gsad";
}

1;
