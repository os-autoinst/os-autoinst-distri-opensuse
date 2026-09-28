# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package:  'rsyslog-module-ossl',rsyslog-module-dtls
# Summary: This would allow TLS support using OpenSSL (stable backend),
#          avoiding the unstable GnuTLS path and rsyslog-module-dtls adds
#          DTLS support for secure log transport over UDP
#
# When you install rsyslog-module-ossl, it gives rsyslog the ability to use the lmnsd_ossl driver.
# This allows you to:
# Encrypt log traffic: Securely stream logs from a client machine to a centralized log server using TLS.
# Authenticate endpoints: Use X.509 certificates to ensure that your log server only accepts logs from
# trusted clients, and clients only send logs to a verified server.
#
# Client configuration
# Purpose: Enables OpenSSL encryption (TLS) for outbound logs
#
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

sub dtls_supported {
    return !script_run('ls /usr/lib*/rsyslog/imdtls.so /usr/lib*/rsyslog/omdtls.so');
}

sub run {
    select_serial_terminal;

    install_package('rsyslog-module-ossl openssl', trup_reboot => 1);
    eval { install_package("rsyslog-module-dtls", trup_reboot => 1) };
    if ($@) {
        record_info('DTLS', 'rsyslog-module-dtls not available on this product - continuing without DTLS');
    }
    my $dtls = dtls_supported();
    record_info('DTLS', $dtls ? 'imdtls/omdtls available' : 'imdtls/omdtls not shipped - DTLS phase skipped');

    mutex_wait 'server_is_ready';
    assert_script_run 'mkdir -p /etc/rsyslog-certs';
    assert_script_run 'curl -o /etc/rsyslog.d/10-tls-client.conf ' . data_url('rsyslog/10-tls-client.conf');
    if ($dtls) {
        assert_script_run 'curl -o /etc/rsyslog.d/20-dtls-client.conf ' . data_url('rsyslog/20-dtls-client.conf');
        exec_and_insert_password 'scp -o StrictHostKeyChecking=no root@server:/etc/rsyslog-certs/client-cert.pem /etc/rsyslog-certs';
        exec_and_insert_password 'scp -o StrictHostKeyChecking=no root@server:/etc/rsyslog-certs/client-key.pem /etc/rsyslog-certs';
    }
    exec_and_insert_password 'scp -o StrictHostKeyChecking=no root@server:/etc/rsyslog-certs/ca.pem /etc/rsyslog-certs';
    assert_script_run 'rsyslogd -N1';

    my $journald_cfg = '/etc/systemd/journald.conf /etc/systemd/journald.conf.d/ /usr/lib/systemd/journald.conf.d/';
    assert_script_run "grep -rq '^ForwardToSyslog=yes' $journald_cfg || "
      . "echo -e '[Journal]\\nForwardToSyslog=yes' > /etc/systemd/journald.conf.d/99-forward-to-syslog.conf";
    systemctl 'restart systemd-journald';
    assert_script_run '! journalctl -u rsyslog --since "-1min" --no-pager | grep -E "could not start|error creating disk queue"';
    systemctl 'restart rsyslog';
    assert_script_run 'echo "TLS_TEST_SUCCESS" | openssl s_client -connect server:6514 -servername server -CAfile /etc/rsyslog-certs/ca.pem -quiet -no_ign_eof';
    if ($dtls) {
        assert_script_run('for i in 1 2 3; do logger -t dtls_test "DTLS_TEST_OK"; sleep 2; done');
    }
    barrier_wait 'rsyslog_setup';
    barrier_wait 'rsyslog_finished';
}
sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    record_info('rsyslog journal', script_output('journalctl -u rsyslog --no-pager -n 100', proceed_on_failure => 1));
    $self->SUPER::post_fail_hook;
}

1;
