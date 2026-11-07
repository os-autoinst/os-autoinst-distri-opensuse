# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Configure the SUT for the ipaddr2 test
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

ipaddr2/configure.pm - Configure the SUT for the ipaddr2 test

=head1 DESCRIPTION

This module handles the post-deployment configuration of the System Under
Test (SUT) virtual machines for the ipaddr2 test.

It performs the following key configuration steps:

- Establishes SSH connectivity by accepting host keys for the bastion
  and between the two SUT VMs.
- Generates SSH keys on the SUT VMs to allow passwordless communication between them.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider. Currently, only AZURE is supported.

=item B<IPADDR2_CLOUDINIT>

Controls whether this module performs the web server configuration.
If set to 0 (disabled), this module will install and configure nginx.
If enabled (default, 1), this step is skipped, assuming cloud-init has already performed it.

=item B<IPADDR2_ROOTLESS>

Determines the user for internal SSH key generation. If set to 0, keys are
generated for the 'root' user. Otherwise, the default user (for example, 'cloudadmin') is used.

=item B<IPADDR2_KEYCHECK_OLD>

A compatibility flag for older SSH clients. If set to 1, it uses a less strict
host key checking mechanism ('no') suitable for older systems where 'accept-new' is not supported.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal qw( select_serial_terminal );
use version_utils qw( is_sle );
use sles4sap::ipaddr2 qw(
  ipaddr2_bastion_key_accept
  ipaddr2_bastion_pubip
  ipaddr2_bastion_wait_ssh
  ipaddr2_internal_key_accept
  ipaddr2_bastion_sshd_override
  ipaddr2_internal_sshd_override
  ipaddr2_internal_key_gen
  ipaddr2_post_fail_hook
);

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    record_info("TEST STAGE", "Prepare all the ssh connections within the 2 internal VMs");
    my $bastion_ip = ipaddr2_bastion_pubip();
    die "Problem getting bastion public IP" unless $bastion_ip;
    ipaddr2_bastion_wait_ssh(bastion_ip => $bastion_ip);
    my $ret = ipaddr2_bastion_key_accept(bastion_ip => $bastion_ip);
    die "Bastion key accept failed with exit code $ret" if $ret;

    # Deal with ssh banner / tcp forwarding in >=16 images: the bastion first, as ssh -J needs it
    if (is_sle('>=16.0')) {
        $ret = ipaddr2_bastion_sshd_override(bastion_ip => $bastion_ip);
        die "Bastion sshd override failed with exit code $ret" if $ret;
    }

    my %int_key_args = (bastion_ip => $bastion_ip);
    # unsupported option "accept-new" for default ssh used in 12sp5
    $int_key_args{key_checking} = 'no' if (check_var('IPADDR2_KEYCHECK_OLD', '1'));
    $ret = ipaddr2_internal_key_accept(%int_key_args);
    die "Internal key accept failed with exit code $ret" if $ret;

    # Same on the internal VMs, reachable now through the bastion: crm init/join ssh between them
    if (is_sle('>=16.0')) {
        $ret = ipaddr2_internal_sshd_override(bastion_ip => $bastion_ip);
        die "Internal VMs sshd override failed with exit code $ret" if $ret;
    }

    # default for ipaddr2_internal_key_gen is cloudadmin
    $int_key_args{user} = 'root' unless check_var('IPADDR2_ROOTLESS', '1');
    ipaddr2_internal_key_gen(%int_key_args);
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    ipaddr2_post_fail_hook();
}

1;
