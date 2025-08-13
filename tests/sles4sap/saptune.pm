# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: saptune
# Summary: saptune availability test
# Maintainer: QE-SAP <qe-sap@suse.de>, Alvaro Carvajal <acarvajal@suse.de>

use base 'sles4sap';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(systemctl zypper_call);
use version_utils qw(is_sle is_upgrade);
use Utils::Architectures;

=head1 NAME

sles4sap/saptune.pm - Smoke test for saptune package in SLES for SAP

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=head1 DESCRIPTION

This module will check C<saptune> is installed, and it will also check if the
corresponding service has been started in SLES for SAP 16 or newer.

B<The key tasks performed by this module include:>

=over

=item * Check with C<systemctl> the status of the C<saptune> service on SLES for SAP 16 or newer.

=item * Check C<saptune> is installed with C<saptune version> command.

=back

=cut

sub run {
    select_serial_terminal;

    # Skip test on migration
    return if is_upgrade();

    # saptune is not installed by default on SLES4SAP 12 on ppc64le
    zypper_call '-n in saptune' if (is_ppc64le() and is_sle('<15'));

    systemctl 'status saptune' if is_sle('>=16');

    assert_script_run 'saptune version';
}

1;
