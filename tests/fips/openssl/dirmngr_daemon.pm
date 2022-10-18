# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: gpg2
# Summary: Test dirmngr daemon and valid/revoked certificate
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#52430, poo#52937, tc#1729313, poo#65375

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub dirmngr_daemon {

    my $self = shift;
    select_serial_terminal;

    my $myca_dir = "/home/linux/myca";

    # Create dirmngr required testing folder
    assert_script_run("mkdir -p /etc/dirmngr/");
    assert_script_run("mkdir -p /etc/gnupg/trusted-certs");
    assert_script_run('mkdir -p /var/{run,log}/dirmngr /var/cache/dirmngr/crls.d /var/lib/dirmngr/extra-certs');

    # Create an empty ldapservers.conf
    assert_script_run "touch /etc/dirmngr/ldapservers.conf";

    # Crete dirmngr config file
    assert_script_run("echo 'log-file /var/log/dirmngr/dirmngr.log' > /etc/dirmngr/dirmngr.conf");

    # Copy trusted CA certificates to /etc/dirmngr/trusted-certs
    assert_script_run("cp $myca_dir/ca/root-ca.crt.der /etc/gnupg/trusted-certs");

    # Start dirmngr as daemon, Disable ldap, Load CRL
    assert_script_run("dirmngr --daemon --disable-ldap --load-crl $myca_dir/crl/root-ca.crl.der");

    # part of softfailure https://dev.gnupg.org/T5531
    assert_script_run("openssl x509 -inform der -outform pem -text -in $myca_dir/certs/test2.crt.der -out $myca_dir/certs/test2.crt.pem");
    assert_script_run("openssl x509 -inform der -outform pem -text -in $myca_dir/certs/test1.crt.der -out $myca_dir/certs/test1.crt.pem");

    # Verify certificate ( test2.crt.der certificate is valid)
    if (script_run("dirmngr-client --validate $myca_dir/certs/test2.crt.der 2>&1 | tee -a /tmp/cert2.out") == 0) {
        assert_script_run("grep -o \'dirmngr-client: certificate is valid\' /tmp/cert2.out");
    } elsif (script_run("dirmngr-client --validate $myca_dir/certs/test2.crt.pem 2>&1 | tee -a /tmp/cert2.out") == 0) {
        record_soft_failure 'Maniphest#T5531: dirmngr --validate broken for DER encoded files';
    }
    else {
        die "dirmngr-client did not exit with return 0";
    }

    # Verify certificate ( test1.crt.der certificate is revoked)
    if (script_run("dirmngr-client --validate $myca_dir/certs/test1.crt.der 2>&1 | tee -a /tmp/cert1.out") == 1) {
        assert_script_run("grep -o \'dirmngr-client: validation of certificate failed: Certificate revoked\' /tmp/cert1.out");
    } elsif (script_run("dirmngr-client --validate $myca_dir/certs/test1.crt.pem 2>&1 | tee -a /tmp/cert2.out") == 1) {
        record_soft_failure 'Maniphest#T5531: dirmngr --validate broken for DER encoded files';
    }
    else {
        die "dirmngr-client did not exit with return 1";
    }
}

sub run {

    my ($self) = @_;

    # Test Dirmngr daemon
    $self->dirmngr_daemon();
}

sub test_flags {
    return {fatal => 0};
}

1;
