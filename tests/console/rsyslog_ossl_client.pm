# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package:  'rsyslog-module-ossl'
# Summary: This would allow TLS support using OpenSSL (stable backend),
#          avoiding the unstable GnuTLS path.

# When you install rsyslog-module-ossl, it gives rsyslog the ability to use the lmnsd_ossl driver.
# This allows you to:
# Encrypt log traffic: Securely stream logs from a client machine to a centralized log server using TLS.
# Authenticate endpoints: Use X.509 certificates to ensure that your log server only accepts logs from
# trusted clients, and clients only send logs to a verified server.
#
# Client configuration
# Purpose: Enables OpenSSL encryption (TLS) for outbound logs.
#
# 1. Establishes a secure TLS handshake with the central log server.
# 2. Encrypts the local system logs before they leave the machine.
# 3. Prevents "eavesdropping" (packet sniffing) and tampering while logs
#    are in transit across the network.
#
# Maintainer: qe-core <qe-core@suse.com>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use mmapi;
use utils;
use version_utils;
use package_utils 'install_package';

sub run {
    select_serial_terminal;
    install_package('rsyslog-module-ossl openssl', trup_reboot => 1);
    mutex_wait 'server_is_ready';
    assert_script_run 'mkdir -p /etc/rsyslog-certs';
    assert_script_run 'curl -o /etc/rsyslog.d/10-tls-client.conf ' . data_url('rsyslog/10-tls-client.conf');
    exec_and_insert_password 'scp -o StrictHostKeyChecking=no root@server:/etc/rsyslog-certs/ca.pem /etc/rsyslog-certs';
    systemctl 'restart rsyslog';
    assert_script_run 'echo "TLS_TEST_SUCCESS" | openssl s_client -connect server:6514 -servername server -CAfile /etc/rsyslog-certs/ca.pem -quiet -no_ign_eof';
}

1;
