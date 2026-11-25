# SUSE's openQA tests
#
# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper functions for the Trento RPM tests
# Maintainer: Trento team <trento-developers@suse.com>

package trento::rpm;

use strict;
use warnings;
use base 'Exporter';
use Exporter;
use testapi;
use utils qw(zypper_call);

=head1 SYNOPSIS

Library with helpers to deploy and validate Trento from RPM packages,
using the repositories of a maintenance incident.

=cut

our @EXPORT = qw(
  trento_rpm_install_ansible_trento
);

=head2 trento_rpm_install_ansible_trento

    trento_rpm_install_ansible_trento();

Install ansible-trento. The package comes from the incident when the incident
includes it, and from the released repositories otherwise.

=cut

sub trento_rpm_install_ansible_trento {
    zypper_call('in ansible-trento');
    record_info('ansible-trento', script_output('rpm -q ansible-trento'));
}

1;
