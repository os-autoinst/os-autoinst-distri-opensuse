# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Per TPM2 stack, we would like to add the tpm2-tss-engine,
#          For tpm2_enginee tests, we need tpm2-abrmd serive active.
#          We have several test modules, this test module will cover
#          the self signed tests.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64902, tc#1742298

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    # Self Signed certificate generate operation
    my $test_dir = "tpm2_engine_self_sign";
    my $tss_file = "rsa.tss";
    my $crt_file = "rsa.tst";
    assert_script_run "mkdir $test_dir";
    assert_script_run "cd $test_dir";
    assert_script_run "tpm2tss-genkey -a rsa $tss_file";
    assert_script_run "expect -c 'spawn openssl req -new -x509 -engine tpm2tss -key $tss_file -keyform engine -out $crt_file; 
expect \"Country Name (2 letter code) \\[AU\\]\"; send \"CN\\r\";
expect \"State or Province Name (full name) \\[Some-State\\]:\"; send \"Beijing\\r\";
expect \"Locality Name (eg, city) \\[\\]:\"; send \"Beijing\\r\";
expect \"Organization Name (eg, company) \\[Internet Widgits Pty Ltd\\]:\"; send \"SUSE\\r\";
expect \"Organizational Unit Name (eg, section) \\[\\]:\"; send \"QA\\r\";
expect \"Common Name (e.g. server FQDN or YOUR name) \\[\\]:\"; send \"richard\\r\";
expect \"Email Address \\[\\]:\"; send \"richard.fan\@suse.com\\r\";
expect {
    \"error\" {
      exit 139
   }
   eof {
       exit 0
   }
}'";
    assert_script_run "ls |grep $crt_file";
    assert_script_run "cd";
}

1;
