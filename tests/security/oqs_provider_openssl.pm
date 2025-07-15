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

    if (script_run('zypper se oqs-provider') == 104) {
        record_info('SKIPPING TEST', "oqs-provider is not available on this system.");
        return;
    }
    zypper_call("in openssl oqs-provider");

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
activate = 1
module = /usr/lib64/ossl-modules/oqsprovider.so
EOF

    script_output("echo '$conf' >> $conf_file");
    assert_script_run("export OPENSSL_CONF=$conf_file");

    my $output = script_output("openssl list -provider oqs -public-key-algorithms | grep oqs | grep -E 'p256_mayo2|x25519_frodo640aes|p256_bikel1|rsa3072_falcon512'");
    my ($algo) = $output =~ /(p256_mayo2|x25519_frodo640aes|p256_bikel1|rsa3072_falcon512)/;
    defined $algo ? record_info("Selected algo: $algo") : die "No expected OQS algorithm found!";
    my $key_path = "/root/$algo-key.pem";

    assert_script_run("openssl genpkey -provider oqs -algorithm $algo -out $key_path");
    # Sign a message with the generated key
    my $test_file = "/tmp/input.txt";
    my $sig_file = "/tmp/input.sig";
    assert_script_run("echo 'openQA test' > $test_file");
    assert_script_run("openssl pkeyutl -sign -provider oqs -inkey $key_path -out $sig_file -in $test_file");

    # Verify the signature using the same key
    assert_script_run("openssl pkeyutl -verify -provider oqs -inkey $key_path -sigfile $sig_file -in $test_file");
}

sub test_flags {
    return {fatal => 1};
}

1;
