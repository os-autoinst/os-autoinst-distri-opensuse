# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: gnutls
# Summary: SLES15SP2 FIPS certification, we need to certify gnutls and libnettle
#          In this case, will configure GnuTLS server
# Maintainer: QE Security <none@suse.de>
# Tags: poo#63223, tc#1744099

use base "consoletest";
use testapi;
use strict;
use warnings;
use utils qw(zypper_call);

sub run {
    select_console "root-console";
    zypper_call 'in gnutls';

    # Create test folder
    my $test_dir = "gnutls";
    assert_script_run "rm -rf $test_dir";
    assert_script_run "mkdir $test_dir && cd $test_dir";

    # Add support for X.509.  First we generate a CA
    my $pri_ca_key = "x509-ca-key.pem";
    my $pri_ca_out = "x509-ca.pem";
    my $ca_tmpl = "ca.tmpl";
    my $ca_tmpl_cont = <<'EOF';
cn = GnuTLS test CA
ca
cert_signing_key
EOF
    assert_script_run "certtool --generate-privkey > $pri_ca_key";
    assert_script_run "echo '$ca_tmpl_cont' > $ca_tmpl";
    assert_script_run "certtool --generate-self-signed --load-privkey $pri_ca_key --template $ca_tmpl --outfile $pri_ca_out";

    # Generate a server certificate
    my $set_pri_key = "x509-server-key.pem";
    my $set_ca_out = "x509-server.pem";
    my $set_tmpl = "server.tmpl";
    my $set_tmpl_cont = <<'EOF';
organization = GnuTLS test server
cn = test.gnutls.org
tls_www_server
encryption_key
signing_key
dns_name = test.gnutls.org
EOF
    assert_script_run "certtool --generate-privkey > $set_pri_key";
    assert_script_run "echo '$set_tmpl_cont' > $set_tmpl";
    assert_script_run
"certtool --generate-certificate --load-privkey $set_pri_key --load-ca-certificate $pri_ca_out --load-ca-privkey $pri_ca_key --template $set_tmpl --outfile $set_ca_out";

    #  Generate a client certificate
    my $cli_pri_key = "x509-client-key.pem";
    my $cli_out = "x509-client.pem";
    my $cli_tmpl = "client.tmpl";
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
    my $user = "psk_identity";
    my $passwd = "psk-passwd.txt";
    assert_script_run "psktool -u $user -p $passwd";

    # Start a server with support for PSK. This would require a password file created with psktool
    type_string "nohup gnutls-serv --http --priority NORMAL:+ECDHE-PSK:+PSK --pskpasswd $passwd&";
    send_key 'ret';
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
