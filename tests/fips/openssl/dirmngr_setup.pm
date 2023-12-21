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
use transactional qw(trup_call process_reboot);
use utils qw(zypper_call);
use version_utils qw(is_transactional);

sub create_test_certificate {
    my ($ca_cfg, $crt_csr, $crt_key, $crt, $ssl_pwd) = @_;
    assert_script_run("openssl req -new -config $ca_cfg -out $crt_csr -keyout $crt_key -passout 'pass:$ssl_pwd'");
    assert_script_run("openssl ca -batch -config $ca_cfg -in $crt_csr -out $crt -passin 'pass:$ssl_pwd'");
}

sub convert_to_der {
    my ($file, $param) = @_;
    assert_script_run("openssl $param -in $file -outform der -out $file.der");
}

sub dirmngr_setup {
    my $myca_dir = "/home/linux/myca";
    my $ssl_pwd = "susetesting";

    assert_script_run("mkdir -p $myca_dir && cd $myca_dir");
    assert_script_run('mkdir -p ca/root-ca/private ca/root-ca/db crl certs etc');
    assert_script_run("chmod 700 ca/root-ca/private");

    # Create root-ca database
    assert_script_run("cp /dev/null ca/root-ca/db/root-ca.db");
    assert_script_run("cp /dev/null ca/root-ca/db/root-ca.db.attr");
    assert_script_run('echo 01 > ca/root-ca/db/root-ca.crt.srl');
    assert_script_run('echo 01 > ca/root-ca/db/root-ca.crl.srl');

    if (is_transactional) {
        trup_call("pkg install dirmngr");
        process_reboot(trigger => 1);
        select_console 'root-console';
        assert_script_run("cd $myca_dir");
    } else {
        zypper_call("--no-refresh in dirmngr");
    }

    my $ca_cfg = "$myca_dir/etc/root-ca.conf";
    assert_script_run("curl --silent " . data_url('openssl/root-ca/root-ca.conf') . " --output $ca_cfg");

    my $ca_csr = "$myca_dir/ca/root-ca.csr";
    my $ca_key = "$myca_dir/ca/root-ca/private/root-ca.key";
    my $ca_crt = "$myca_dir/ca/root-ca.crt";
    my $ca_crl = "$myca_dir/crl/root-ca.crl";

    # Create root ca certificate
    assert_script_run("openssl req -new -config $ca_cfg -out $ca_csr -keyout $ca_key -passout 'pass:$ssl_pwd'");
    assert_script_run("openssl ca -selfsign -batch -config $ca_cfg -in $ca_csr -out $ca_crt -extensions root_ca_ext -enddate 20301231235959Z -passin 'pass:$ssl_pwd'");
    assert_script_run("openssl ca -gencrl -config $ca_cfg -out $ca_crl -passin 'pass:$ssl_pwd'");

    my $crt_csr_t1 = "$myca_dir/certs/test1.csr";
    my $crt_key_t1 = "$myca_dir/certs/test1.key";
    my $crt_t1 = "$myca_dir/certs/test1.crt";

    my $crt_csr_t2 = "$myca_dir/certs/test2.csr";
    my $crt_key_t2 = "$myca_dir/certs/test2.key";
    my $crt_t2 = "$myca_dir/certs/test2.crt";

    # Create test certificates (test1.crt)
    create_test_certificate("$ca_cfg", "$crt_csr_t1", "$crt_key_t1", "$crt_t1", "$ssl_pwd");

    # Create test certificates (test2.crt)
    create_test_certificate("$ca_cfg", "$crt_csr_t2", "$crt_key_t2", "$crt_t2", "$ssl_pwd");

    # Revoke test1.crt but keep test2.crt
    assert_script_run("openssl ca -revoke $crt_t1 -config $ca_cfg -passin 'pass:$ssl_pwd'");

    # Update the CRL
    assert_script_run("openssl ca -gencrl -config $ca_cfg -out $ca_crl -passin 'pass:$ssl_pwd'");

    # Convert certificates to DER for dirmngr
    convert_to_der("$ca_crt", "x509");
    convert_to_der("$ca_crl", "crl");
    convert_to_der("$crt_t1", "x509");
    convert_to_der("$crt_t2", "x509");
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
