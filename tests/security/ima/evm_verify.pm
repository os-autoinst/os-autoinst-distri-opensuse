# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test EVM verify function provided by evmctl
# Maintainer: QE Security <none@suse.de>
# Tags: poo#53585

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $test_app = "/usr/bin/yes";
    my $mok_priv = "/root/certs/key.asc";
    my $cert_der = "/root/certs/ima_cert.der";
    my $mok_pass = "suse";

    assert_script_run "$test_app --version";

    assert_script_run "evmctl sign -p$mok_pass -k $mok_priv $test_app";
    validate_script_output "getfattr -m security.evm -d $test_app", sub {
        # Base64 armored security.ima content (358 chars), we do not match the
        # last three ones here for simplicity
        m/security\.evm=[0-9a-zA-Z+\/]{355}/;
    };
    assert_script_run "evmctl verify -k $cert_der $test_app";

    # Empty evm attribute and verify
    assert_script_run "setfattr -x security.evm $test_app";
    validate_script_output "evmctl verify -k $cert_der $test_app || true", sub {
        m/No data available/;
    };
}

sub test_flags {
    return {always_rollback => 1};
}

1;
