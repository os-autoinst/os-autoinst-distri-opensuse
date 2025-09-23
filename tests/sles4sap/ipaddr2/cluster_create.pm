# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Create cluster
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ipaddr2/cluster_create.pm - Create the Pacemaker cluster for the ipaddr2 test

=head1 DESCRIPTION

This module is responsible for setting up the Pacemaker cluster on the two
SUT (System Under Test) virtual machines.

Its primary tasks are:

- If cloud-init was disabled (B<IPADDR2_CLOUDINIT> is 0), it installs the nginx web server
  on both SUT nodes.
  This step is necessary because without cloud-init, the web server would not
  have been pre-installed.
- Initializes and configures the Pacemaker cluster across the two SUT nodes,
  preparing them for high-availability resource management.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider. This module currently only supports 'AZURE'.

=item B<IPADDR2_CLOUDINIT>

A flag that determines if the nginx web server needs to be installed by this module.
If set to 0, this module will handle the installation. If enabled (1), it assumes
cloud-init has already installed it.

=item B<IPADDR2_NGINX_EXTREPO>

An external repository URL for the nginx package. This is only used if B<IPADDR2_CLOUDINIT>
is disabled and nginx is not available in the default system repositories.

=item B<IPADDR2_ROOTLESS>

A flag passed to the cluster creation function to determine the configuration context,
for example, if the cluster is set up by a non-root user.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use sles4sap::ipaddr2 qw(
  ipaddr2_configure_web_server
  ipaddr2_bastion_pubip
  ipaddr2_cluster_create
  ipaddr2_cluster_check_version
  ipaddr2_cleanup
  ipaddr2_logs_collect);

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    my $bastion_ip = ipaddr2_bastion_pubip();

    # Check if cloudinit is active or not. In case it is,
    # registration was eventually there and no need to per performed here.
    if (check_var('IPADDR2_CLOUDINIT', 0)) {
        record_info("TEST STAGE", "Install the web server");
        my %web_install_args;
        $web_install_args{external_repo} = get_var('IPADDR2_NGINX_EXTREPO') if get_var('IPADDR2_NGINX_EXTREPO');
        $web_install_args{bastion_ip} = $bastion_ip;
        foreach (1 .. 2) {
            $web_install_args{id} = $_;
            ipaddr2_configure_web_server(%web_install_args);
        }
    }

    record_info("TEST STAGE", "Init and configure the Pacemaker cluster");

    ipaddr2_cluster_check_version();
    ipaddr2_cluster_create(
        bastion_ip => $bastion_ip,
        rootless => get_var('IPADDR2_ROOTLESS', '0'));
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    ipaddr2_logs_collect();
    ipaddr2_cleanup(
        diagnostic => get_var('IPADDR2_DIAGNOSTIC', 0),
        cloudinit => get_var('IPADDR2_CLOUDINIT', 1),
        ibsm_rg => get_var('IBSM_RG'));
    $self->SUPER::post_fail_hook;
}

1;
