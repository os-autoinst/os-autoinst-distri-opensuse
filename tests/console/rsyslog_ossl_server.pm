# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package:  'rsyslog-module-ossl'
# Summary: This would allow TLS support using OpenSSL (stable backend),
#          avoiding the unstable GnuTLS path, and DTLS support for secure
#          rsyslog log transport over UDP.

# When you install rsyslog-module-ossl, it gives rsyslog the ability to use the lmnsd_ossl driver.
# This allows you to:
# Encrypt log traffic: Securely stream logs from a client machine to a centralized log server using TLS.
# Authenticate endpoints: Use X.509 certificates to ensure that your log server only accepts logs from
# trusted clients, and clients only send logs to a verified server.
#
# rsyslog-module-dtls provides the imdtls/omdtls modules, which bring the same
# encryption and X.509 authentication to UDP transport, where plain TLS cannot be
# used. It keeps the low overhead and fire-and-forget delivery of UDP syslog while
# protecting the datagrams in transit.
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

use constant DTLS_PORT => 4433;

sub dtls_supported {
    return !script_run('ls /usr/lib*/rsyslog/imdtls.so /usr/lib*/rsyslog/omdtls.so');
}

sub run {
    select_serial_terminal;
    barrier_create('rsyslog_setup', 2);
    barrier_create('rsyslog_finished', 2);
    install_package('rsyslog-module-ossl openssl', trup_reboot => 1);
    # The package is only shipped on Tumbleweed, so the install is allowed
    # to fail on other products - $dtls below decides whether the DTLS phase runs.
    eval { install_package("rsyslog-module-dtls", trup_reboot => 1) };
    if ($@) {
        record_info('DTLS', 'rsyslog-module-dtls not available on this product - continuing without DTLS');
    }

    my $dtls = dtls_supported();
    record_info('DTLS', $dtls ? 'imdtls/omdtls available' : 'imdtls/omdtls not shipped - DTLS phase skipped');

    assert_script_run 'mkdir -p /etc/rsyslog-certs;cd /etc/rsyslog-certs';
    assert_script_run 'curl -o /etc/rsyslog.d/10-tls-server.conf ' . data_url('rsyslog/10-tls-server.conf');
    assert_script_run('curl -o /etc/rsyslog.d/20-dtls-server.conf ' . data_url('rsyslog/20-dtls-server.conf')) if $dtls;

    assert_script_run 'openssl req -new -x509 -extensions v3_ca -keyout ca-key.pem -out ca.pem -days 365 -nodes -subj "/CN=TestCA"';

    assert_script_run "echo 'subjectAltName=DNS:server' > server-ext.cnf";
    assert_script_run 'openssl req -new -nodes -keyout server-key.pem -out server.csr -subj "/CN=server"';
    assert_script_run 'openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -days 365 -extfile server-ext.cnf';

    assert_script_run "echo 'subjectAltName=DNS:client' > client-ext.cnf";
    assert_script_run 'openssl req -new -nodes -keyout client-key.pem -out client.csr -subj "/CN=client"';
    assert_script_run 'openssl x509 -req -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out client-cert.pem -days 365 -extfile client-ext.cnf';
    assert_script_run 'openssl verify -CAfile ca.pem server-cert.pem client-cert.pem';

    assert_script_run 'chmod 700 /etc/rsyslog-certs';
    assert_script_run 'chmod 600 /etc/rsyslog-certs/*.pem';
    assert_script_run 'rsyslogd -N1';
    if ($dtls) {
        assert_script_run 'semanage port -a -t syslogd_port_t -p udp ' . DTLS_PORT
          . ' || semanage port -m -t syslogd_port_t -p udp ' . DTLS_PORT;
        record_info('selinux port', script_output('semanage port -l | grep -w ' . DTLS_PORT));
    }
    systemctl 'restart rsyslog';
    if (!script_run('systemctl is-active firewalld')) {
        assert_script_run 'firewall-cmd --add-port=6514/tcp' . ($dtls ? ' --add-port=' . DTLS_PORT . '/udp' : '');
    }
    assert_script_run 'ss -tlnp | grep 6514';
    mutex_create 'server_is_ready';
    barrier_wait 'rsyslog_setup';
    assert_script_run 'grep -R "TLS_TEST_SUCCESS" /var/log/remote/';
    if ($dtls) {
        script_retry 'grep -h "DTLS_TEST_OK" /var/log/remote/dtls-*.log', delay => 10, retry => 6;
        record_info('dtls log', script_output('cat /var/log/remote/dtls-*.log'));
    }
    barrier_wait 'rsyslog_finished';
    wait_for_children;

}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    record_info('rsyslog journal', script_output('journalctl -u rsyslog --no-pager -n 100', proceed_on_failure => 1));
    record_info('udp sockets', script_output('ss -ulnp', proceed_on_failure => 1));
    record_info('remote logs', script_output('ls -l /var/log/remote/ 2>&1', proceed_on_failure => 1));
    $self->SUPER::post_fail_hook;
}
1;
