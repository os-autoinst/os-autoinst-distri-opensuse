# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Per TPM2 stack, we would like to add the tpm2-tss-engine,
#          For tpm2_enginee tests, we need tpm2-abrmd serive active.
#          We have several test modules, this test module will generate
#          ramdom data with hex 10.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64902, tc#1742298

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    my $self = shift;
    select_serial_terminal;

    # Random data
    validate_script_output "openssl rand -engine tpm2tss -hex 10  2>&1", sub { m/engine\s\"tpm2tss\"\sset/ };
}

1;
