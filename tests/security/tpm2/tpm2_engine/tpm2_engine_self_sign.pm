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
# Summary: Per TPM2 stack, we would like to add the tpm2-tss-engine,
#          For tpm2_enginee tests, we need tpm2-abrmd serive active.
#          We have several test modules, this test module will cover
#          the self signed tests.
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#64902, tc#1742298

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

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

sub test_flags {
    return {always_rollback => 1};
}

1;
