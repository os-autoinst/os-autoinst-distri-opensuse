# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Base module for OpenSSL Certificate Authority
#          The corresponding key pairs can be use in
#          a number of situations, such as issuing server
#          certificates to secure an intranet website, or
#          for issuing certificates to clients to allow them
#          to authenticate to a server
# Maintainer: QE Security <none@suse.de>
# Tags: poo#88513, tc#1768672

package opensslca;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use utils;

our @EXPORT = qw(self_sign_ca);

# Function "self_sign_ca" is used for generating self-signed CA and server key pair
# At the same time, it should verify the certification before using it
sub self_sign_ca {
    my ($ca_dir, $cn_name) = @_;

    assert_script_run qq(rm -rf $ca_dir);
    assert_script_run qq(mkdir -p $ca_dir);
    assert_script_run qq(cd $ca_dir);
    # generate CA keypair with keUsage extension. Note that CA's CN must differ from server CN
    my $openssl_cmd = qq(openssl req -new -x509 -newkey rsa:2048 -keyout myca.key -days 3560 -out myca.pem -nodes) .
      qq( -subj "/C=CN/ST=Beijing/L=Beijing/O=QA/OU=security/CN=$cn_name.ca.example.com") .
      qq( -addext "keyUsage=digitalSignature,keyEncipherment,dataEncipherment,cRLSign,keyCertSign");    # poo128213
    assert_script_run $openssl_cmd;
    assert_script_run qq(openssl genrsa -out server.key 2048);
    assert_script_run qq(openssl req -new -key server.key -out server.csr -subj "/C=CN/ST=Beijing/L=Beijing/O=QA/OU=security/CN=$cn_name.example.com");
    assert_script_run qq(openssl x509 -req -days 3560 -CA myca.pem -CAkey myca.key -CAcreateserial -in server.csr -out server.pem);
    assert_script_run qq(openssl pkcs12 -export -inkey server.key -in server.pem -out crt.p12 -nodes -name Server-Cert -password pass:"");
    assert_script_run qq(openssl verify -verbose -CAfile myca.pem server.pem);
}

1;
