# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Library sub and shared data for the cloud zypper patch test.

package sles4sap::cloud_zypper_patch;
use strict;
use warnings FATAL => 'all';
use testapi;
use Carp qw(croak);
use Exporter qw(import);
use mmapi qw(get_current_job_id);
use sles4sap::azure_cli;
use publiccloud::utils qw(get_ssh_private_key_path);


=head1 SYNOPSIS

Library to manage the sles4sap cloud zypper patch tests
=cut

our @EXPORT = qw(
  zp_azure_deploy
  zp_azure_destroy
  zp_azure_netpeering
  zp_ssh_connect
  zp_add_repos
  zp_zypper_patch
);

use constant DEPLOY_PREFIX => 'zp';

our $user = 'cloudadmin';
our $pub_ip = DEPLOY_PREFIX . '_pub_ip';
our $vnet = DEPLOY_PREFIX . '_vnet';


=head2 zp_azure_resource_group

  my $rg = zp_azure_resource_group();

Get the Azure resource group name for this test
=cut

sub zp_azure_resource_group {
    return DEPLOY_PREFIX . get_current_job_id();
}

=head2 zp_azure_deploy

    zp_azure_deploy(region => 'northeurope', os => 'SUSE:sles-sap-15-sp5:gen2:latest');

Create a deployment in Azure designed for this specific test.

1. Create a resource group to contain all
2. Create a vnet and subnet in it
3. Create one Public IP
4. Create 1 VM

=over 2

=item B<region> - existing resource group

=item B<os> - existing Load balancer NAME

=back
=cut

sub zp_azure_deploy {
    my (%args) = @_;
    foreach (qw(region os)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    az_version();

    my $rg = zp_azure_resource_group();

    az_group_create(
        name => $rg,
        region => $args{region});

    my $subnet = DEPLOY_PREFIX . '-snet';
    az_network_vnet_create(
        resource_group => $rg,
        region => $args{region},
        vnet => $vnet);

    az_network_publicip_create(
        resource_group => $rg,
        name => $pub_ip,
        sku => 'Basic',
        allocation_method => 'Static');

    az_vm_create(
        resource_group => $rg,
        name => DEPLOY_PREFIX . '_vm',
        region => $args{region},
        image => $args{os},
        username => $user,
        vnet => $vnet,
        snet => $subnet,
        ssh_pubkey => get_ssh_private_key_path() . '.pub',
        public_ip => $pub_ip);
}

=head2 zp_azure_destroy

    zp_azure_destroy();

Destroy the deployment by deleting the resource group and created network peering

=over 1

=item B<target_rg> - (optional) name of the resource group of the IBSm

=back
=cut

sub zp_azure_destroy {
    my (%args) = @_;
    my $rg = zp_azure_resource_group();
    az_group_delete(name => $rg, timeout => 600);

    if ($args{target_rg}) {
        my $target_vnet = az_network_vnet_get(resource_group => $args{target_rg});
        my $target_vnet_name = @$target_vnet[0];
        az_network_peering_delete(
            name => zp_ibsm2sut_peering_name(target_rg => $args{target_rg}, target_vnet_name => $target_vnet_name),
            resource_group => $args{target_rg},
            vnet => $target_vnet_name);
    }
}

=head2 zp_ibsm2sut_peering_name

    my $peering_name = zp_ibsm2sut_peering_name(target_rg => get_required_var('ZP_IBSM_RG'));

Get the Azure resource group name for this test

=over 2

=item B<target_rg> - name of the resource group of the IBSm

=item B<target_vnet_name> - (optional) name of the VNET of the IBSm, if not provided it is calculated internally

=back
=cut

sub zp_ibsm2sut_peering_name {
    my (%args) = @_;
    croak("Argument < target_rg > missing") unless $args{target_rg};
    my $target_vnet_name;
    if ($args{target_vnet_name}) {
        $target_vnet_name = $args{target_vnet_name};
    } else {
        my $target_vnet = az_network_vnet_get(resource_group => $args{target_rg});
        $target_vnet_name = @$target_vnet[0];
    }

    return join('-', $args{target_rg}, $target_vnet_name, $vnet);
}

=head2 zp_azure_netpeering

    zp_azure_netpeering(target_rg => get_required_var('ZP_IBSM_RG'))

=over 1

=item B<target_rg> - name of the resource group of the IBSm

=back
=cut

sub zp_azure_netpeering {
    my (%args) = @_;
    croak("Argument < target_rg > missing") unless $args{target_rg};

    my $rg = zp_azure_resource_group();

    my $target_vnet = az_network_vnet_get(resource_group => $args{target_rg});
    my $target_vnet_name = @$target_vnet[0];

    az_network_peering_create(
        name => join('-', $rg, $vnet, $target_vnet_name),
        source_rg => $rg,
        source_vnet => $vnet,
        target_rg => $args{target_rg},
        target_vnet => $target_vnet_name);
    az_network_peering_create(
        name => zp_ibsm2sut_peering_name(target_rg => $args{target_rg}, target_vnet_name => $target_vnet_name),
        source_rg => $args{target_rg},
        source_vnet => $target_vnet_name,
        target_rg => $rg,
        target_vnet => $vnet);

    az_network_peering_list(resource_group => $rg, vnet => $vnet);
    az_network_peering_list(resource_group => $args{target_rg}, vnet => $target_vnet_name);
}

=head2 zp_ssh_connect
    
    zp_ssh_connect()

First ssh connections
=cut 

sub zp_ssh_connect {
    my $pubip_addr = az_network_publicip_get(
        resource_group => zp_azure_resource_group(),
        name => $pub_ip);

    assert_script_run("ssh -o StrictHostKeyChecking=accept-new $user\@$pubip_addr whoami");
    assert_script_run("ssh $user\@$pubip_addr whoami");
    assert_script_run("ssh $user\@$pubip_addr whoami | grep $user");
}

=head2 zp_add_repos

    zp_add_repos()

Add MU repos to the zypper list
=cut

sub zp_add_repos {
    my (%args) = @_;
    foreach (qw(ip name repos)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my @repos = split(/,/, $args{repos});
    my $count = 0;
    my $pubip_addr = az_network_publicip_get(
        resource_group => zp_azure_resource_group(),
        name => $pub_ip);
    my $cmd;

    $cmd = join(' ', 'ssh',
        "$user\@$pubip_addr",
        "'sudo echo \"$args{ip} $args{name}\" | sudo tee -a /etc/hosts'");
    #"'sudo sed -i \\\$a $args{ip} $args{name} /etc/hosts'");
    assert_script_run($cmd);

    $cmd = join(' ', 'ssh',
        "$user\@$pubip_addr",
        "'sudo cat /etc/hosts'");
    assert_script_run($cmd);

    while (defined(my $maintrepo = shift @repos)) {
        next if $maintrepo =~ /^\s*$/;
        if ($maintrepo =~ /Development-Tools/ or $maintrepo =~ /Desktop-Applications/) {
            record_info("MISSING REPOS",
                "There are repos in this incident, that are not uploaded to IBSM. ($maintrepo). Later errors, if they occur, may be due to these.");
            next;
        }
        $cmd = join(' ', 'ssh',
            "$user\@$pubip_addr",
            "'sudo zypper --no-gpg-checks ar -f -n TEST_$count $maintrepo TEST_$count'");
        assert_script_run($cmd);
        $count++;
    }
    $cmd = join(' ', 'ssh',
        "$user\@$pubip_addr",
        "'sudo zypper -n ref'");
    assert_script_run($cmd);
}

=head2 zp_zypper_patch

    zp_zypper_patch()

Run zypper patch
=cut

sub zp_zypper_patch {
    my $pubip_addr = az_network_publicip_get(
        resource_group => zp_azure_resource_group(),
        name => $pub_ip);
    my $cmd = join(' ', 'ssh',
        "$user\@$pubip_addr",
        "'sudo zypper --non-interactive patch --auto-agree-with-licenses --no-recommends'");
    assert_script_run($cmd);
}

1;
