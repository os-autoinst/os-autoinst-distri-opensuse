# Copyright (C) 2020 SUSE LLC
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
# Summary: SLES15SP2 FIPS certification, we need to certify gnutls and libnettle
#          In this case, will configure GnuTLS server
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#63223, tc#1744099

use base "consoletest";
use testapi;
use strict;
use warnings;

sub run {
    select_console "root-console";

    # Create test folder
    my $test_dir = "gnutls";
    assert_script_run "mkdir $test_dir && cd $test_dir";

    # Add support for X.509.  First we generate a CA
    my $pri_ca_key   = "x509-ca-key.pem";
    my $pri_ca_out   = "x509-ca.pem";
    my $ca_tmpl      = "ca.tmpl";
    my $ca_tmpl_cont = <<'EOF';
cn = GnuTLS test CA
ca
cert_signing_key
EOF
    assert_script_run "certtool --generate-privkey > $pri_ca_key";
    assert_script_run "echo '$ca_tmpl_cont' > $ca_tmpl";
    assert_script_run "certtool --generate-self-signed --load-privkey $pri_ca_key --template $ca_tmpl --outfile $pri_ca_out";

    # Generate a server certificate
    my $ser_pri_key   = "x509-server-key.pem";
    my $ser_ca_out    = "x509-server.pem";
    my $ser_tmpl      = "server.tmpl";
    my $ser_tmpl_cont = <<'EOF';
organization = GnuTLS test server
cn = test.gnutls.org
tls_www_server
encryption_key
signing_key
dns_name = test.gnutls.org
EOF
    assert_script_run "certtool --generate-privkey > $ser_pri_key";
    assert_script_run "echo '$ser_tmpl_cont' > $ser_tmpl";
    assert_script_run
"certtool --generate-certificate --load-privkey $ser_pri_key --load-ca-certificate $pri_ca_out --load-ca-privkey $pri_ca_key --template $ser_tmpl --outfile $ser_ca_out";

    #  Generate a client certificate
    my $cli_pri_key   = "x509-client-key.pem";
    my $cli_out       = "x509-client.pem";
    my $cli_tmpl      = "client.tmpl";
    my $cli_tmpl_cont = <<'EOF';
cn = GnuTLS test client
tls_www_client
encryption_key
signing_key
EOF
    assert_script_run "certtool --generate-privkey > $cli_pri_key";
    assert_script_run "echo '$cli_tmpl_cont' > $cli_tmpl";
    assert_script_run
"certtool --generate-certificate --load-privkey $cli_pri_key --load-ca-certificate $pri_ca_out --load-ca-privkey $pri_ca_key --template $cli_tmpl --outfile $cli_out";

    # Create password file with psktool
    my $user   = "psk_identity";
    my $passwd = "psk-passwd.txt";
    assert_script_run "psktool -u $user -p $passwd";

    # Start a server with support for PSK. This would require a password file created with psktool
    type_string "nohup gnutls-serv --http --priority NORMAL:+ECDHE-PSK:+PSK --pskpasswd $passwd&";
    type_string "\n";
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
