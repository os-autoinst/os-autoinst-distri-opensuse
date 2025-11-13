# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Per TPM2 stack, we would like to add the tpm2-tss-engine,
#          For tpm2_enginee tests, we need tpm2-abrmd serive active.
#          We have several test modules, this test module will cover
#          the self signed tests.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64902, tc#1742298

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    my $test_dir = "tpm2_engine_self_sign_$$";
    my $tss_file = "rsa.tss";
    my $crt_file = "rsa.crt";
    my $subject = "/C=CZ/ST=Prague/L=Prague/O=SUSE/OU=QA/CN=geeko";
    assert_script_run "mkdir $test_dir; cd $test_dir";
    assert_script_run "tpm2tss-genkey -a rsa $tss_file";
    assert_script_run "openssl req -new -x509 -engine tpm2tss -key $tss_file -keyform engine -out $crt_file -subj \"$subject\"";
    assert_script_run "openssl x509 -in $crt_file -noout -text";
    assert_script_run "cd; rm -rf $test_dir";
}

1;
