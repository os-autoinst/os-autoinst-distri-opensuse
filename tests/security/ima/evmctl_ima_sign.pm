# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test evmctl ima_sign options
# Note: This case should come after 'ima_apprasial_digital_signatures'
# Maintainer: QE Security <none@suse.de>
# Tags: poo#50333

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $sample_dir = '/tmp/ima_tests';
    my $sample_file1 = "$sample_dir/foo";
    my $sample_file2 = "$sample_dir/foodir/foo2";

    my $mok_priv = '/root/certs/key.asc';
    my $cert_der = '/root/certs/ima_cert.der';
    my $mok_pass = 'suse';

    # Not all the options will be tested here, some of them have already
    # been avaiable in other IMA cases

    # Test -r (--recursive) option
    assert_script_run "mkdir -p $sample_dir/foodir";
    assert_script_run "echo 'foo test' > $sample_file1";
    assert_script_run "echo 'foo foo test' > $sample_file2";

    assert_script_run "evmctl -a sha256 ima_sign -p$mok_pass -k $mok_priv -r $sample_dir";
    foreach my $g ($sample_file1, $sample_file2) {
        validate_script_output "getfattr -m . -d $g", sub {
            # Base64 armored security.ima content (358 chars), we do not match
            # the last three ones here for simplicity
            m/security\.ima=[0-9a-zA-Z+\/]{355}/;
        };
    }

    # Test -f (--sigfile) option
    assert_script_run "evmctl -a sha256 ima_sign -p$mok_pass -k $mok_priv -f $sample_file1";
    assert_script_run("test -e $sample_file1.sig", fail_message => 'Signature file (.sig) has not been created');
    assert_script_run("evmctl ima_verify -k $cert_der $sample_file1", fail_message => 'Signature verification failed');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
