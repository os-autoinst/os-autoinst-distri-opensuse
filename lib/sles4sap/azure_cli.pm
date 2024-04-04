# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>

package sles4sap::azure_cli;
use strict;
use warnings;
use testapi;
use Carp qw(croak);
use Exporter qw(import);
use Regexp::Common qw(net);

=head1 SYNOPSIS

Library to compose and run Azure cli commands
=cut

our @EXPORT = qw(
  az_group_create
  az_network_vnet_create
  az_network_nsg_create
  az_network_nsg_rule_create
  az_network_publicip_create
  az_network_lb_create
  az_vm_as_create
  az_vm_create
  az_vm_openport
  az_nic_id_get
  az_nic_name_get
  az_ipconfig_name_get
);


=head2 az_group_create

    az_group_create( name => 'openqa-rg', region => 'westeurope');

=over 2

=item B<name> - full name of the resource group

=item B<region> - Azure region

=back
=cut

sub az_group_create {
    my (%args) = @_;
    foreach (qw(name region)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    # Create a resource group to contain all deployed resources
    my $az_cmd = join(' ', 'az group create',
        '--name', $args{name},
        '--location', $args{region});
    assert_script_run($az_cmd);
}

=head2 az_network_vnet_create

    az_network_vnet_create(
        resource_group => 'openqa-rg',
        region => 'westeurope',
        vnet => 'openqa-vnet',
        snet => 'openqa-subnet',
        address_prefixes => '10.0.1.0/16',
        subnet_prefixes => '10.0.1.0/24')

    Create a virtual network

=over 6

=item B<resource_group> - existing resource group where to create the network

=item B<region> - Azure region

=item B<vnet> - name of the virtual network

=item B<snet> - name of the subnet

=item B<address_prefixes> - virtual network ip address space. Default 192.168.0.0/16

=item B<subnet_prefixes> - subnet ip address space. Default 192.168.0.0/24

=back
=cut

sub az_network_vnet_create {
    my (%args) = @_;
    foreach (qw(resource_group region vnet snet)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{address_prefixes} //= '192.168.0.0/16';
    $args{subnet_prefixes} //= '192.168.0.0/24';
    my $az_cmd = join(' ', 'az network vnet create',
        '--resource-group', $args{resource_group},
        '--location', $args{region},
        '--name', $args{vnet},
        '--address-prefixes', $args{address_prefixes},
        '--subnet-name', $args{snet},
        '--subnet-prefixes', $args{subnet_prefixes});
    assert_script_run($az_cmd);
}

=head2 az_network_nsg_create

    az_network_nsg_create(
        resource_group => 'openqa-rg',
        name => 'openqa-nsg')

    Create a network security group

=over 2

=item B<resource_group> - existing resource group where to create the NSG

=item B<name> - security group name

=back
=cut

sub az_network_nsg_create {
    my (%args) = @_;
    foreach (qw(resource_group name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $az_cmd = join(' ', 'az network nsg create',
        '--resource-group', $args{resource_group},
        '--name', $args{name});
    assert_script_run($az_cmd);
}

=head2 az_network_nsg_rule_create

    az_network_nsg_rule_create(
        resource_group => 'openqa-rg',
        nsg => 'openqa-nsg',
        name => 'openqa-nsg-rule-ssh',
        port => 22)

    Create a rule for an existing network security group

=over 2

=item B<resource_group> - existing resource group where to create the NSG

=item B<nsg> - existing security group name

=item B<name> - security rule name

=item B<port> - allowed port

=back
=cut

sub az_network_nsg_rule_create {
    my (%args) = @_;
    foreach (qw(resource_group nsg name port)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $az_cmd = join(' ', 'az network nsg rule create',
        '--resource-group', $args{resource_group},
        '--nsg-name', $args{nsg},
        '--name', $args{name},
        "--protocol '*'",
        '--direction inbound',
        "--source-address-prefix '*'",
        "--source-port-range '*'",
        "--destination-address-prefix '*'",
        '--destination-port-range', $args{port},
        '--access allow',
        '--priority 200');
    assert_script_run($az_cmd);
}


=head2 az_network_publicip_create

    az_network_publicip_create(
        resource_group => 'openqa-rg',
        name => 'openqa-pip',
        zone => '1 2 3')

    Create an IPv4 public IP resource

=over 5

=item B<resource_group> - existing resource group where to create the PubIP

=item B<name> - public IP resource name

=item B<sku> - default Standard

=item B<allocation_method> - optionally add --allocation-method

=item B<zone> - optionally add --zone

=back
=cut

sub az_network_publicip_create {
    my (%args) = @_;
    foreach (qw(resource_group name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{sku} //= 'Standard';
    my $alloc_cmd = $args{allocation_method} ? '--allocation-method ' . $args{allocation_method} : '';
    my $zone_cmd = $args{zone} ? '--zone ' . $args{zone} : '';
    my $az_cmd = join(' ', 'az network public-ip create',
        '--resource-group', $args{resource_group},
        '--name', $args{name},
        '--version IPv4',
        '--sku', $args{sku},
        $alloc_cmd,
        $zone_cmd);
    assert_script_run($az_cmd);
}

=head2 az_network_lb_create

    az_network_lb_create(
        resource_group => 'openqa-rg',
        name => 'openqa-lb',
        vnet => 'openqa-vnet',
        snet => 'openqa-subnet',
        backend => 'openqa-be',
        frontend_ip => 'openqa-feip',
        sku => 'Standard')

    Create a load balancer entity.
    LB is mostly "just" a "group" definition
    to link back-end and front-end resources (usually an IP)
    # SKU Standard (and not Basic) is needed to get some Metrics

=over 8

=item B<resource_group> - existing resource group where to create lb

=item B<name> - load balancer name

=item B<vnet> - existing Virtual network name where to create LB in

=item B<snet> - existing Subnet network name where to create LB in

=item B<backend> - name to assign to created backend pool

=item B<frontend_ip> - name to assign to created frontend ip, will be reused in "az network lb rule create"

=item B<sku> - default Basic

=item B<fip> - optionally add --private-ip-address

=back
=cut

sub az_network_lb_create {
    my (%args) = @_;
    foreach (qw(resource_group name vnet snet backend frontend_ip)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    $args{sku} //= 'Basic';
    my $fip_cmd = $args{fip} ? "--private-ip-address $args{fip}" : '';

    my $az_cmd = join(' ', 'az network lb create',
        '--resource-group', $args{resource_group},
        '-n', $args{name},
        '--sku', $args{sku},
        '--vnet-name', $args{vnet},
        '--subnet', $args{snet},
        '--backend-pool-name', $args{backend},
        '--frontend-ip-name', $args{frontend_ip},
        $fip_cmd);
    assert_script_run($az_cmd);
}

=head2 az_vm_as_create

    az_vm_as_create(
        resource_group => 'openqa-rg',
        name => 'openqa-as',
        region => 'westeurope',
        fault_count => 2)

    Create an availability set. Later on VM can be assigned to it.

=over 4

=item B<resource_group> - existing resource group where to create the Availability set

=item B<region> - region where to create the Availability set

=item B<name> - availability set name

=item B<fault_count> - value for --platform-fault-domain-count

=back
=cut

sub az_vm_as_create {
    my (%args) = @_;
    foreach (qw(resource_group name region)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $fc_cmd = $args{fault_count} ? "--platform-fault-domain-count $args{fault_count}" : '';

    my $az_cmd = join(' ', 'az vm availability-set create',
        '--resource-group', $args{resource_group},
        '-n', $args{name},
        '-l', $args{region},
        $fc_cmd);
    assert_script_run($az_cmd);
}

=head2 az_vm_create

    az_vm_create(
        resource_group => 'openqa-rg',
        name => 'openqa-vm',
        region => 'westeurope',
        image => 'SUSE:sles-sap-15-sp5:gen2:latest')

    Create a virtual machine

=over 14

=item B<name> - virtual machine name

=item B<resource_group> - existing resource group where to create the VM

=item B<image> - OS image name

=item B<vnet> - optional name of the Virtual Network where to place the VM

=item B<snet> - optional name of the SubNet where to connect the VM

=item B<size> - VM size, default Standard_B1s

=item B<region> - optional region where to create the VM

=item B<availability_set> - optional inclusion in an availability set

=item B<username> - optional admin username

=item B<nsg> - optional inclusion in an network security group

=item B<nic> - optional add to the VM a NIC created separately with 'az network nic create'

=item B<public_ip> - optional add to the VM a public IP. Value like "" is a valid one and
                     is not the same as not including the argument at all.

=item B<custom_data> - optional provide a cloud-init script file

=item B<ssh_pubkey> - optional inclusion in an availability set,
          if missing the command is configured to generate one

=back
=cut

sub az_vm_create {
    my (%args) = @_;
    foreach (qw(resource_group name image)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    $args{size} //= 'Standard_B1s';
    my $region_cmd = $args{region} ? "-l $args{region}" : '';
    my $as_cmd = $args{availability_set} ? "--availability-set $args{availability_set}" : '';
    my $user_cmd = $args{username} ? "--admin-username $args{username}" : '';
    my $nsg_cmd = $args{nsg} ? "--nsg $args{nsg}" : '';
    my $cd_cmd = $args{custom_data} ? "--custom-data $args{custom_data}" : '';
    my $nic_cmd = $args{nic} ? "--nics $args{nic}" : '';
    my $pip_cmd = $args{public_ip} ? "--public-ip-address $args{public_ip}" : '';
    my $vnet_cmd = $args{vnet} ? "--vnet-name $args{vnet}" : '';
    my $snet_cmd = $args{snet} ? "--subnet $args{snet}" : '';
    my $ssh_cmd = $args{ssh_pubkey} ? "--ssh-key-values $args{ssh_pubkey}" : '--authentication-type ssh --generate-ssh-keys';

    my $az_cmd = join(' ', 'az vm create',
        '--resource-group', $args{resource_group},
        '-n', $args{name},
        '--size', $args{size},
        '--image', $args{image},
        '--public-ip-address ""',
        $region_cmd, $as_cmd, $vnet_cmd, $snet_cmd, $user_cmd, $nsg_cmd, $cd_cmd, $nic_cmd, $pip_cmd, $ssh_cmd);
    assert_script_run($az_cmd, timeout => 600);
}


=head2 az_vm_openport

    az_vm_openport(
        resource_group => 'openqa-rg',
        name => 'openqa-vm',
        port => 80)

    Open a port on an existing VM

=over 3

=item B<resource_group> - existing resource group where to create the Availability set

=item B<name> - name of an existing VM

=item B<port> - port to open

=back
=cut

sub az_vm_openport {
    my (%args) = @_;
    foreach (qw(resource_group name port)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $az_cmd = join(' ', 'az vm open-port',
        '--resource-group', $args{resource_group},
        '--name', $args{name},
        '--port', $args{port});
    assert_script_run($az_cmd);
}


=head2 az_vm_wait_cloudinit

    az_vm_wait_cloudinit(
        resource_group => 'openqa-rg',
        name => 'openqa-vm')

    Wait cloud-init completition on a running VM

=over 4

=item B<resource_group> - existing resource group where to create the Availability set

=item B<name> - name of an existing VM

=item B<username> - username default cloudadmin

=item B<timeout> - max wait time in seconds. Default 3600.

=back
=cut

sub az_vm_wait_cloudinit {
    my (%args) = @_;
    foreach (qw(resource_group name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{username} //= 'cloudadmin';
    $args{timeout} //= 3600;

    my $az_cmd = join(' ', 'az vm run-command create',
        '--resource-group', $args{resource_group},
        '--run-command-name "awaitCloudInitIsDone"',
        '--vm-name', $args{name},
        '--async-execution "false"',
        '--run-as-user', $args{username},
        '--timeout-in-seconds', $args{timeout},
        '--script "sudo cloud-init status --wait"');
    assert_script_run($az_cmd);
}


=head2 az_nic_id_get

    my $nic_id = az_nic_id_get(
        resource_group => 'openqa-rg',
        name => 'openqa-vm')

    get the NIC ID of the first NIC of a given VM

=over 2

=item B<resource_group> - existing resource group where to create the Availability set

=item B<name> - name of an existing VM

=back
=cut


sub az_nic_id_get {
    my (%args) = @_;
    foreach (qw(resource_group name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $az_cmd = join(' ', 'az vm show',
        '--resource-group', $args{resource_group},
        '-n', $args{name},
        '--query "networkProfile.networkInterfaces[0].id"',
        '-o tsv');
    return script_output($az_cmd);
}

=head2 az_nic_get

    get the NIC data from NIC ID

=over 2

=item B<nic_id> - existing NIC ID (eg. from az_nic_id_get)

=item B<filter> - query filter

=back
=cut

sub az_nic_get {
    my (%args) = @_;
    foreach (qw(nic_id filter)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $az_cmd = join(' ', 'az network nic show',
        '--id', $args{nic_id},
        '--query "' . $args{filter} . '"',
        '-o tsv');
    return script_output($az_cmd);
}

=head2 az_nic_name_get

    my $nic_name = az_nic_name_get(
        resource_group => 'openqa-rg',
        name => 'openqa-vm')

    get the NIC name from NIC ID

=over 2

=item B<nic_id> - existing NIC ID (eg. from az_nic_id_get)

=back
=cut

sub az_nic_name_get {
    my (%args) = @_;
    foreach (qw(nic_id)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    return az_nic_get(nic_id => $args{nic_id}, filter => 'name');
}

=head2 az_ipconfig_name_get

    my $ipconfig_name = az_ipconfig_name_get(
        resource_group => 'openqa-rg',
        name => 'openqa-vm')

    get the name of the first IpConfig of a NIC from a NIC ID

=over 2

=item B<nic_id> - existing NIC ID (eg. from az_nic_id_get)

=back
=cut

sub az_ipconfig_name_get {
    my (%args) = @_;
    foreach (qw(nic_id)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return az_nic_get(nic_id => $args{nic_id}, filter => 'ipConfigurations[0].name');
}
