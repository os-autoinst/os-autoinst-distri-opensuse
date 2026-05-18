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
# Sever configuration
# Purpose: Enables OpenSSL encryption (TLS) on the receiving server.
#
# 1. Listens for incoming log streams encrypted with TLS.
# 2. Uses the server's private key and certificate to decrypt the logs.
# 3. Validates the client's certificate (if mutual authentication is enabled)
#    to ensure only trusted machines can send logs to this server.
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
    install_package('rsyslog-module-ossl', trup_reboot => 1);
    assert_script_run 'mkdir -p /etc/rsyslog-certs;cd /etc/rsyslog-certs';
    assert_script_run 'curl -o /etc/rsyslog.d/10-tls-server.conf ' . data_url('rsyslog/10-tls-server.conf');
    assert_script_run 'openssl req -new -x509 -extensions v3_ca -keyout ca-key.pem -out ca.pem -days 365 -nodes -subj "/CN=TestCA"';
    assert_script_run 'openssl req -new -nodes -keyout server-key.pem -out server.csr -subj "/"';
    assert_script_run 'openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -days 365';
    assert_script_run 'chmod 700 /etc/rsyslog-certs';
    assert_script_run 'chmod 600 /etc/rsyslog-certs/*.pem';
    systemctl 'restart rsyslog';
    assert_script_run 'ss -tlnp | grep 6514';
    mutex_create 'server_is_ready';
    wait_for_children;
    assert_script_run 'grep -R "TLS_TEST_SUCCESS" /var/log/remote/';
}

1;
