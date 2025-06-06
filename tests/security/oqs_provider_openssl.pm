# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: run upstream testsuite of OQS Provider
#
# Maintainer: QE Security <none@suse.de>

use strict;
use warnings;
use base 'opensusebasetest';
use serial_terminal 'select_serial_terminal';
use testapi;
use utils 'zypper_call';
use version_utils qw(is_sle);

sub run {
    select_serial_terminal;

    if (zypper_call("--no-refresh if oqs-provider") != 0) {
        record_info('SKIPPING TEST', "Skipping test due to missing oqs-provider package.");
    } else {
        zypper_call("in gcc wget cmake openssl oqs-provider");

        my $conf_file = '/etc/ssl/oqs-openssl.cnf';
        my $conf = <<EOF;
openssl_conf = openssl_init

[openssl_init]
providers = provider_sect

[provider_sect]
default = default_sect
oqs = oqs_sect

[default_sect]
activate = 1

[oqs_sect]
module = /usr/lib64/ossl-modules/oqsprovider.so
EOF

        script_output("echo '$conf' >> $conf_file");
        assert_script_run("export OPENSSL_CONF=$conf_file");
        assert_script_run("openssl list -provider oqs -public-key-algorithms | grep -q dilithium2");

        my $key_path = "/root/dilithium2-key.pem";
        assert_script_run("openssl genpkey -provider oqs -algorithm dilithium2 -out $key_path");
        # Sign a message with the generated key
        my $test_file = "/tmp/input.txt";
        my $sig_file = "/tmp/input.sig";
        assert_script_run("echo 'openQA test' > $test_file");
        assert_script_run("openssl pkeyutl -sign -provider oqs -inkey $key_path -out $sig_file -in $test_file");

        # Verify the signature using the same key
        assert_script_run("openssl pkeyutl -verify -provider oqs -inkey $key_path -sigfile $sig_file -in $test_file");
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
