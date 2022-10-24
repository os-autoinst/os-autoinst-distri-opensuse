# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: saptune availability test
# Maintainer: QE-SAP <qe-sap@suse.de>, Alvaro Carvajal <acarvajal@suse.de>

use base "sles4sap";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils "zypper_call";
use version_utils qw(is_sle is_upgrade);
use Utils::Architectures;
use strict;
use warnings;

sub run {
    select_serial_terminal;

    # Skip test on migration
    return if is_upgrade();

    # saptune is not installed by default on SLES4SAP 12 on ppc64le
    zypper_call "-n in saptune" if (is_ppc64le() and is_sle('<15'));

    assert_script_run "saptune version";
}

1;
