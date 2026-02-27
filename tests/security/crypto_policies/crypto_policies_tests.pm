# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Switch crypto-policies, reboot and verify sshd is running
# Maintainer: QE Security <none@suse.de>

use base 'opensusebasetest';
use v5.20;
use feature qw(signatures);
no warnings qw(experimental::signatures);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use power_action_utils 'power_action';
use Utils::Backends 'is_pvm';
use Utils::Architectures;

sub run {
    my ($self) = @_;
    my @services = qw{sshd named};
    select_serial_terminal;
    setup_bind();
    setup_gnutls();
    setup_nss();
    foreach my $s (@services) {
        systemctl "enable --now $s.service";
    }
    for my $policy ('LEGACY', 'BSI', 'FUTURE', 'DEFAULT') {
        $self->set_policy($policy);
        # check the services are running after policy change
        foreach my $s (@services) {
            validate_script_output "systemctl status $s.service", sub { m/active \(running\)/ };
        }
        ensure_bind_is_working();
        ensure_gnutls_is_working();
        ensure_nss_is_working_with($policy);
    }
}

sub setup_bind {
    zypper_call 'in bind';
    assert_script_run('curl ' . data_url('security/crypto_policies/example.com.zone') . ' -o /var/lib/named/master/example.com');
    assert_script_run('curl ' . data_url('security/crypto_policies/example.com.conf') . ' -o /etc/named.d/example.com.conf');
    assert_script_run qq(echo 'include "/etc/named.d/example.com.conf";' >> /etc/named.conf);
}

# simple smoke tests
sub ensure_bind_is_working {
    # validate root DNS signature
    validate_script_output 'delv', sub { m/fully validated/ };
    # query rndc (uses crypto key authentication)
    validate_script_output 'rndc status', sub { m/server is up and running/ };
    # query local authoritative zone
    validate_script_output 'host foobar.example.com localhost', sub { m /foobar.example.com has address 1.2.3.4/ };
}

sub setup_gnutls {
    zypper_call 'in gnutls';
}

sub setup_nss {
    zypper_call 'in mozilla-nss mozilla-nss-tools openssl';
    assert_script_run 'curl -O ' . data_url('security/crypto_policies/test_nss_client.sh');
    assert_script_run 'chmod +x test_nss_client.sh';
}

sub ensure_nss_is_working_with($policy) {
    # run the test script with each policy
    my $logfile = "nss_client_${policy}_policy.txt";
    assert_script_run("./test_nss_client.sh $logfile");
    upload_logs $logfile;
    # check if result is good
    assert_script_run('grep "HTTP/1.0 200 ok" ' . $logfile);
    assert_script_run('grep "1 server accepts (SSL_accept())" ' . $logfile);
    # cleanup for next run
    assert_script_run "rm -rf localhost.pem localhost.key nssdb";
}

sub ensure_gnutls_is_working {
    # generate a CA, and a server certificate
    my $ca_key_file = 'x509-ca-key.pem';
    my $ca_cert_file = 'x509-ca.pem';
    my $srv_key_file = 'x509-server-key.pem';
    my $srv_cert_file = 'x509-server.pem';
    my $ca_template_file = 'ca.tmpl';
    my $srv_template_file = 'server.tmpl';
    my $srv_log_file = 'gnutls-serv.log';
    assert_script_run $_ for (
        "certtool --generate-privkey > $ca_key_file",
        "echo 'cn = GnuTLS test CA' > $ca_template_file",
        "echo 'ca' >> $ca_template_file",
        "echo 'cert_signing_key' >> $ca_template_file",
        "certtool --generate-self-signed --load-privkey $ca_key_file --template $ca_template_file --outfile $ca_cert_file",
        "certtool --generate-privkey > $srv_key_file",
        "echo 'organization = GnuTLS test server' > $srv_template_file",
        "echo 'cn = localhost' >> $srv_template_file",
        "echo 'tls_www_server' >> $srv_template_file",
        "echo 'encryption_key' >> $srv_template_file",
        "echo 'signing_key' >> $srv_template_file",
    );
    assert_script_run("certtool --generate-certificate --load-privkey $srv_key_file --load-ca-certificate $ca_cert_file --load-ca-privkey $ca_key_file --template $srv_template_file --outfile $srv_cert_file", timeout => 300);
    # spin up a server on localhost (5556 = default port) and wait for the server to be active
    my $pid = background_script_run "gnutls-serv -p 5556 --echo --x509cafile $ca_cert_file --x509keyfile $srv_key_file --x509certfile $srv_cert_file > $srv_log_file 2>&1";
    script_retry "grep 'Echo Server listening' $srv_log_file";
    # use the client to test the TLS connection
    validate_script_output_retry "echo helloSUSE | gnutls-cli -p 5556 localhost --x509cafile=$ca_cert_file",
      sub { m/Status: The certificate is trusted.*Handshake was completed.*helloSUSE/s };
    # stop the server and cleanup
    assert_script_run "kill $pid";
    assert_script_run "rm $ca_key_file $ca_cert_file $ca_template_file $srv_key_file $srv_cert_file $srv_template_file";
}

sub set_policy {
    my ($self, $policy) = @_;
    assert_script_run "update-crypto-policies --set $policy";
    power_action('reboot', textmode => 1);
    reconnect_mgmt_console if is_pvm();
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    select_serial_terminal;
    # ensure the current policy has been applied
    validate_script_output 'update-crypto-policies --show', sub { m/$policy/ };
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
