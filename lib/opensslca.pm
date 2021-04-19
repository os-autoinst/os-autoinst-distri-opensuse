# Copyright (C) 2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Base module for OpenSSL Certificate Authority
#          The corresponding key pairs can be use in
#          a number of situations, such as issuing server
#          certificates to secure an intranet website, or
#          for issuing certificates to clients to allow them
#          to authenticate to a server
# Maintainer: rfan1 <richard.fan@suse.com>
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

    assert_script_run("rm -rf $ca_dir");
    assert_script_run("mkdir -p $ca_dir");
    assert_script_run("cd $ca_dir");
    assert_script_run(
        "openssl req -new -x509 -newkey rsa:2048 -keyout myca.key -days 3560 -out myca.pem -nodes -subj \"/C=CN/ST=Beijing/L=Beij
ing/O=QA/OU=security/CN=$cn_name.example.com\""
    );
    assert_script_run("openssl genrsa -out server.key 2048");
    assert_script_run("openssl req -new -key server.key -out server.csr -subj \"/C=CN/ST=Beijing/L=Beijing/O=QA/OU=security/CN=$cn_name.example.com\"");
    assert_script_run("openssl x509 -req -days 3560 -CA myca.pem -CAkey myca.key -CAcreateserial -in server.csr -out server.pem");
    assert_script_run("openssl pkcs12 -export -inkey server.key -in server.pem -out crt.p12 -nodes -name Server-Cert -password pass:\"\"");
    assert_script_run("openssl verify -verbose -CAfile myca.pem server.pem");
}

1;
