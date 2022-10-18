# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test IMA verify function provided by evmctl
# Note: This case should come after 'ima_apprasial_digital_signatures'
# Maintainer: QE Security <none@suse.de>
# Tags: poo#49562, poo#92347

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $sample_app = '/usr/bin/yes';

    my $mok_priv = '/root/certs/key.asc';
    my $cert_der = "/root/certs/ima_cert.der";

    if (script_run("grep CONFIG_INTEGRITY_TRUSTED_KEYRING=y /boot/config-`uname -r`") == 0) {
        record_soft_failure("bsc#1157432 for SLE15SP2+: CA could not be loaded into the .ima or .evm keyring");
    }
    else {
        # Make sure IMA is in the enforce mode
        validate_script_output "grep -E 'ima_appraise=(fix|log|off)' /etc/default/grub || echo 'IMA enforced'", sub { m/IMA enforced/ };
        assert_script_run("test -e /etc/sysconfig/ima-policy", fail_message => 'ima-policy file is missing');
        assert_script_run "evmctl ima_sign -a sha256 -k $mok_priv $sample_app";

        validate_script_output "getfattr -m security.ima -d $sample_app", sub {
            # Base64 armored security.ima content (358 chars), we do not match the
            # last three ones here for simplicity
            m/security\.ima=[0-9a-zA-Z+\/]{355}/;
        };
        assert_script_run "evmctl ima_verify -k $cert_der $sample_app";

        assert_script_run "setfattr -x security.ima $sample_app";

        validate_script_output "evmctl ima_verify -k $cert_der $sample_app || true", sub {
            m/getxattr\sfailed.*\Q$sample_app\E.*
              No\sdata\savailable/sxx
        };
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
