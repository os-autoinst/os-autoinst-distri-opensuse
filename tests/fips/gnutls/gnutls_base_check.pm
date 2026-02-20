# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: gnutls / libnettle
# Summary: In certified SLE version FIPS certification need to verify gnutls and libnettle
#          In this case, will do some base check for gnutls
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#63223, poo#102770, tc#1744099

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use version_utils qw(is_tumbleweed is_leap is_sle is_transactional is_jeos);
use transactional qw(trup_call process_reboot);

sub install_gnutls {
    # Install the gnutls / libnettle packages (pulled as dependency)
    if (is_transactional) {
        trup_call('pkg install gnutls');
        process_reboot(trigger => 1);
    } else {
        my @pkgs = qw(gnutls);
        push @pkgs, 'sysvinit-tools' if is_jeos && is_sle('<16.0');
        zypper_call("in @pkgs");
    }

    my $current_ver = script_output("rpm -q --qf '%{version}\n' gnutls");
    record_info('gnutls version', "Version of Current gnutls package: $current_ver");

    # gnutls attempt to update to 3.7.2+ in SLE15 SP4 base on the feature
    # SLE-19765: Update libnettle and gnutls to new major versions
    # starting with gnu nettle 3.6+: Support for ED448 signature
    unless (is_sle('<15-SP4') || is_leap('<15.4')) {
        assert_script_run "gnutls-cli --list | tee -a /dev/$serialdev | grep -w SIGN-EdDSA-Ed448";
    }
}

sub validate_gnutls {
    # Check the library is in FIPS kernel mode, and skip checking this in FIPS ENV mode
    # Since ENV mode is not pulled out/installed the fips library
    if (!get_var("FIPS_ENV_MODE")) {
        validate_script_output 'gnutls-cli --fips140-mode 2>&1', sub {
            m/
                library\sis\sin\sFIPS140-[2-3]\smode.*/sx
        };
    }

    # Lists all ciphers, check the certificate types and double confirm TLS1.3,DTLS1.2 and SSL3.0
    assert_script_run 'gnutls-cli -l | grep "Certificate types" | grep "CTYPE-X.509"';
    my $re_proto = is_tumbleweed ? 'grep -e VERS-TLS1.2 -e VERS-TLS1.3 -e VERS-DTLS1.2' : 'grep -e VERS-SSL3.0 -e VERS-TLS1.3 -e VERS-DTLS1.2';
    assert_script_run "gnutls-cli -l | grep Protocols | $re_proto";
}

sub validate_gmail_imap {
    # Check google's imap server and verify basic function
    validate_script_output 'echo | gnutls-cli -d 1 imap.gmail.com -p 993', sub {
        m/
            Certificate\stype:\sX\.509.*
            Status:\sThe\scertificate\sis\strusted.*
            Description:\s\(TLS1\.3.*\).*
            Handshake\swas\scompleted.*/sx
    };
}

sub ensure_self_signed_cerificate_fails {
    # Check self-signed certificate, expecting to fail.
    # Prepare the env
    my $ca_tmpl = 'ca.tmpl';
    my $server_tmpl = 'server.tmpl';
    assert_script_run('mkdir -p /root/cert && cd $_');
    assert_script_run('curl -f ' . data_url("security/gnutls/$ca_tmpl") . " -o $ca_tmpl");
    assert_script_run('curl -f ' . data_url("security/gnutls/$server_tmpl") . " -o $server_tmpl");

    # setup CA
    assert_script_run('certtool --generate-privkey > ca-key.pem');
    assert_script_run('certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca.pem');

    # Generate server Cert
    assert_script_run('certtool --generate-privkey > server-key.pem');
    assert_script_run('certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server.pem');

    # Run test
    background_script_run('gnutls-serv --http --x509cafile ca.pem --x509keyfile server-key.pem --x509certfile server.pem');
    my $bad_result = script_run('echo | gnutls-cli -d 1 localhost -p 443');
    if ($bad_result) {
        my $my_result = '';
        record_info("Invalid certificate as expected: $my_result");
    }
    else {
        die('Certificate should be invalid');
    }
    assert_script_run('kill $(pidof gnutls-serv)');
}

sub run {
    select_serial_terminal;

    install_gnutls();

    validate_gnutls();

    validate_gmail_imap();

    ensure_self_signed_cerificate_fails();
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
