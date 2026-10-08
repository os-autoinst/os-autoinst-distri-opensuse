# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Registration SUT
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ipaddr2/registration.pm - Perform SUT registration for the ipaddr2 test

=head1 DESCRIPTION

This module handles the registration of the SUT (System Under Test) VMs
for the ipaddr2 test.
Its behavior depends on whether cloud-init was used for the initial setup.

If cloud-init is disabled (B<IPADDR2_CLOUDINIT> is 0), this module will:
- Determine the billing model (PAYG, BYOS, or UNKNOWN) via instance-flavor-check
- For PAYG images: wait for guestregister.service to complete (restart if needed)
- For BYOS images: register with SCC using the provided registration code
- For UNKNOWN (bsc#1267739): fall back to SUSEConnect -s to detect status,
  then register if needed
- Register any specified add-on products.

After registration (or if cloud-init was enabled), it refreshes the software repositories
for both SUT VMs and lists them for logging purposes.

=head1 SETTINGS

=over

=item B<IPADDR2_CLOUDINIT>

Controls whether this module performs the registration. Defaults to enabled (1) in the overall test flow.
If set to 0, this module handles the full registration process.
If enabled (not 0), this module skips the registration steps and only refreshes the repositories,
assuming registration was handled by cloud-init during deployment.

=item B<SCC_REGCODE_SLES4SAP>

SUSE Customer Center registration code for SLES for SAP.
Required if B<IPADDR2_CLOUDINIT> is set to 0 and the OS image is a BYOS (Bring Your Own Subscription) type.

=item B<SCC_ADDONS>

A comma-separated list of SUSE Customer Center addons to register.
Each selected addon will require its own registration code in a dedicated variable.
This is used only when B<IPADDR2_CLOUDINIT> is set to 0.

=item B<PUBLIC_CLOUD_SCC_ENDPOINT>

Used by PC B<register_addon>, if not specified the test uses registercloudguest.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use publiccloud::utils;
use sles4sap::ipaddr2 qw(
  ipaddr2_scc_addons
  ipaddr2_scc_check
  ipaddr2_scc_register
  ipaddr2_billing_model_get
  ipaddr2_repo_refresh
  ipaddr2_repo_list
  ipaddr2_bastion_pubip
  ipaddr2_cleanup
  ipaddr2_logs_collect
  ipaddr2_scc_registration_workaround_PAYG);

sub run {
    my ($self) = @_;

    select_serial_terminal;

    my $bastion_ip = ipaddr2_bastion_pubip();

    # Check if cloudinit is active or not. In case it is,
    # registration was eventually performed by the cloudinit script
    # and no need to be performed here.
    if (check_var('IPADDR2_CLOUDINIT', 0)) {
        foreach (1 .. 2) {
            my $type = ipaddr2_billing_model_get(id => $_, bastion_ip => $bastion_ip);
            record_info('BILLING', "VM$_ type:$type");

            if ($type eq 'PAYG') {
                # PAYG images are auto-registered by guestregister.service.
                # Wait for it to complete; restart if it failed.
                ipaddr2_scc_registration_workaround_PAYG(
                    bastion_ip => $bastion_ip,
                    id => $_);
                next;
            }

            if ($type eq 'UNKNOWN') {
                # bsc#1267739: instance-flavor-check failed.
                # Fall back to SUSEConnect -s to determine registration status.
                my $is_registered = ipaddr2_scc_check(
                    bastion_ip => $bastion_ip,
                    id => $_);
                record_info('REG FALLBACK', "is_registered:$is_registered");
                # If already registered, nothing more to do
                next if $is_registered;
                # Otherwise, needs registration like BYOS
                $type = 'BYOS';
            }

            if ($type eq 'BYOS') {
                my %reg_args = (
                    bastion_ip => $bastion_ip,
                    id => $_,
                    scc_code => get_required_var('SCC_REGCODE_SLES4SAP'));
                $reg_args{scc_endpoint} = get_var('PUBLIC_CLOUD_SCC_ENDPOINT')
                  if (get_var('PUBLIC_CLOUD_SCC_ENDPOINT'));
                ipaddr2_scc_register(%reg_args);
            }
        }
        # Optionally register addons
        ipaddr2_scc_addons(
            bastion_ip => $bastion_ip,
            scc_addons => get_required_var('SCC_ADDONS')
        ) if (get_var('SCC_ADDONS'));
    }

    foreach my $id (1 .. 2) {
        # refresh repo
        ipaddr2_repo_refresh(id => $id, bastion_ip => $bastion_ip);
        ipaddr2_repo_list(id => $id, bastion_ip => $bastion_ip);
    }
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    ipaddr2_logs_collect();
    ipaddr2_cleanup(
        diagnostic => get_var('IPADDR2_DIAGNOSTIC', 0),
        cloudinit => get_var('IPADDR2_CLOUDINIT', 1),
        ibsm_rg => get_var('IBSM_RG'));
}

1;
