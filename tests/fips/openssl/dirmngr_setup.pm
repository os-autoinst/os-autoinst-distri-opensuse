# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: openssl
# Summary: Setup dirmngr testing environment - create Root CA,
#          testing ca, testing DER, and CRL
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#52430, poo#52937, tc#1729313

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils;

sub dirmngr_setup {

    my $myca_dir = "/home/linux/myca";

    my $ca_cfg = "$myca_dir/etc/root-ca.conf";
    my $ca_csr = "$myca_dir/ca/root-ca.csr";
    my $ca_crt = "$myca_dir/ca/root-ca.crt";
    my $ca_key = "$myca_dir/ca/root-ca/private/root-ca.key";
    my $ca_crl = "$myca_dir/crl/root-ca.crl";
    my $ssl_pwd = "susetesting";

    # Create myca directories
    assert_script_run("mkdir -p $myca_dir && cd $myca_dir");

    # Create the testing folder in myca
    assert_script_run('mkdir -p ca/root-ca/private ca/root-ca/db crl certs etc');

    # chmod 700 ca/root-ca/private
    assert_script_run("chmod 700 ca/root-ca/private");

    # Create root-ca database:
    assert_script_run("cp /dev/null ca/root-ca/db/root-ca.db");
    assert_script_run("cp /dev/null ca/root-ca/db/root-ca.db.attr");
    assert_script_run 'echo 01 > ca/root-ca/db/root-ca.crt.srl';
    assert_script_run 'echo 01 > ca/root-ca/db/root-ca.crl.srl';

    zypper_call("--no-refresh in dirmngr");

    # Create and download the root-ca.conf file
    assert_script_run "curl --silent " . data_url('openssl/root-ca/root-ca.conf') . " --output $ca_cfg";

    # Create root ca certificate
    my $hashing = is_sle('15-SP6+') ? '-aes256' : '';
    assert_script_run("openssl genrsa $hashing -out $ca_key -passout 'pass:$ssl_pwd' 2048");
    assert_script_run("openssl req -new -config $ca_cfg -out $ca_csr -key $ca_key -passin 'pass:$ssl_pwd' -passout 'pass:$ssl_pwd'");
    assert_script_run("openssl ca -selfsign -batch -config $ca_cfg -in $ca_csr -out $ca_crt -extensions root_ca_ext -enddate 20301231235959Z -passin 'pass:$ssl_pwd'");

    # Create initial CRL
    assert_script_run("openssl ca -gencrl -config $ca_cfg -out $ca_crl -passin 'pass:$ssl_pwd'");

    my $crt_csr_t1 = "$myca_dir/certs/test1.csr";
    my $crt_key_t1 = "$myca_dir/certs/test1.key";
    my $crt_t1 = "$myca_dir/certs/test1.crt";
    my $crt_csr_t2 = "$myca_dir/certs/test2.csr";
    my $crt_key_t2 = "$myca_dir/certs/test2.key";
    my $crt_t2 = "$myca_dir/certs/test2.crt";

    # Create test certificates (test1.crt)
    assert_script_run("openssl genrsa $hashing -out $crt_key_t1 -passout 'pass:$ssl_pwd' 2048");
    assert_script_run("openssl req -new -config $ca_cfg -out $crt_csr_t1 -key $crt_key_t1 -passin 'pass:$ssl_pwd' -passout 'pass:$ssl_pwd'");
    assert_script_run("openssl ca -batch -config $ca_cfg -in $crt_csr_t1 -out $crt_t1 -passin 'pass:$ssl_pwd'");

    # Create test certificates (test2.crt)
    assert_script_run("openssl genrsa $hashing -out $crt_key_t2 -passout 'pass:$ssl_pwd' 2048");
    assert_script_run("openssl req -new -config $ca_cfg -out $crt_csr_t2 -key $crt_key_t2 -passout 'pass:$ssl_pwd' -passin 'pass:$ssl_pwd'");
    assert_script_run("openssl ca -batch -config $ca_cfg -in $crt_csr_t2 -out $crt_t2 -passin 'pass:$ssl_pwd'");

    # Revoke test1.crt but keep test2.crt
    assert_script_run("openssl ca -revoke $crt_t1 -config $ca_cfg -passin 'pass:$ssl_pwd'");

    # Update the CRL
    assert_script_run("openssl ca -gencrl -config $ca_cfg -out $ca_crl -passin 'pass:$ssl_pwd'");

    my $ca_der = "$myca_dir/ca/root-ca.crt.der";
    my $crt_crl_der = "$myca_dir/crl/root-ca.crl.der";
    my $crt_der_t1 = "$myca_dir/certs/test1.crt.der";
    my $crt_der_t2 = "$myca_dir/certs/test2.crt.der";

    # Convert certificates to DER for dirmngr
    assert_script_run("openssl x509 -in $ca_crt -outform der -out $ca_der");
    assert_script_run("openssl crl -in $ca_crl -outform der -out $crt_crl_der");
    assert_script_run("openssl x509 -in $crt_t1 -outform der -out $crt_der_t1");
    assert_script_run("openssl x509 -in $crt_t2 -outform der -out $crt_der_t2");
}

sub run {

    my ($self) = @_;
    select_console 'root-console';

    # Setup Dirmngr
    $self->dirmngr_setup();

}

sub test_flags {
    return {fatal => 1};
}

1;
