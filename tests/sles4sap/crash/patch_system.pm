# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run zypper patch and reboot
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/patch_system.pm - Apply system patches to the SUT

=head1 DESCRIPTION

This module performs a standard system update on the SUT (System Under Test).

It executes `zypper patch` to install all available patches and then reboots
the systems to ensure that all updates, including any kernel updates, are
correctly applied and active. This step helps ensure the SUTs are in a
consistent and up-to-date state for subsequent tests.

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use sles4sap::crash;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    crash_patch_system();
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my %clean_args = (provider => $provider, region => get_required_var('PUBLIC_CLOUD_REGION'));
    $clean_args{availability_zone} = get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE') if $provider eq 'GCE';
    crash_cleanup(%clean_args);
    $self->SUPER::post_fail_hook;
}

1;
