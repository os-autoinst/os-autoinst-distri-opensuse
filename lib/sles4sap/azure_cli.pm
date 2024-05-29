# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Library wrapper around some az cli commands.

package sles4sap::azure_cli;
use strict;
use warnings FATAL => 'all';
use testapi;
use Carp qw(croak);
use Exporter qw(import);
use Mojo::JSON qw(decode_json);


=head1 SYNOPSIS

Library to compose and run Azure cli commands
=cut

our @EXPORT = qw(
  az_version
  az_group_create
  az_group_name_get
  az_network_vnet_create
  az_network_vnet_list
  az_network_vnet_subnet_list
  az_network_vnet_subnet_update
  az_network_nsg_create
  az_network_nsg_rule_create
  az_network_publicip_create
  az_network_publicip_delete
  az_network_publicip_get
  az_network_lb_create
  az_network_lb_probe_create
  az_network_lb_rule_create
  az_network_nat_gateway_create
  az_network_nat_gateway_delete
  az_vm_as_create
  az_vm_create
  az_vm_name_get
  az_vm_openport
  az_vm_wait_cloudinit
  az_vm_instance_view_get
  az_nic_id_get
  az_nic_name_get
  az_ipconfig_name_get
  az_ipconfig_update
  az_ipconfig_pool_add
);


=head2 az_version

    az_version();

Print the version of the az cli available on system
=cut

sub az_version {
    assert_script_run('az --version');
}


=head2 az_group_create

    az_group_create( name => 'openqa-rg', region => 'westeurope');

Create an Azure resource group in a specific region

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

=head2 az_group_name_get

    my $ret = az_group_name_get();

Get the name of all existing Resource groups in the current subscription

=cut

sub az_group_name_get {
    my $az_cmd = join(' ',
        'az group list',
        '--query "[].name"',
        '-o json');
    return decode_json(script_output($az_cmd));
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
    foreach (qw(address_prefixes subnet_prefixes)) {
        croak "Invalid IP range $args{$_} in $_"
          unless ($args{$_} =~ /^[1-9]{1}[0-9]{0,2}\.(0|[1-9]{1,3})\.(0|[1-9]{1,3})\.(0|[1-9]{1,3})\/[0-9]+$/);
    }

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

Create a very specific type of inbound rule for an existing network security group
Just few parameters are configurable here, like the port number

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

=item B<timeout> - optional - override default command execution timeout

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
    assert_script_run($az_cmd, timeout => $args{timeout});
}


=head2 az_network_publicip_delete

    az_network_publicip_delete(
        resource_group => 'openqa-rg',
        name => 'openqa-pip')

Destroy an IPv4 public IP resource, belonging to specified resource group

=over 5

=item B<resource_group> - existing resource group where to destroy the PubIP

=item B<name> - public IP resource name

=item B<timeout> - optional - override default command execution timeout

=back
=cut

sub az_network_publicip_delete {
    my (%args) = @_;
    foreach (qw(resource_group name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    my $az_cmd = join(' ', 'az network public-ip delete',
        '--resource-group', $args{resource_group},
        '--name', $args{name})
    ;
    assert_script_run($az_cmd, timeout => $args{timeout});
}

=head2 az_network_publicip_get

    az_network_publicip_get(
        resource_group => 'openqa-rg',
        name => 'openqa-pip')

Return an IPv4 public IP address from its name

=over 2

=item B<resource_group> - existing resource group including the PubIP

=item B<name> - existing public IP resource name

=back
=cut

sub az_network_publicip_get {
    my (%args) = @_;
    foreach (qw(resource_group name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    my $az_cmd = join(' ', 'az network public-ip show',
        '--resource-group', $args{resource_group},
        '--name', $args{name},
        "--query 'ipAddress'",
        '-o tsv');
    return script_output($az_cmd);
}

=head2 az_network_lb_create

    az_network_lb_create(
        resource_group => 'openqa-rg',
        name => 'openqa-lb',
        vnet => 'openqa-vnet',
        snet => 'openqa-subnet',
        backend => 'openqa-be',
        frontend_ip_name => 'openqa-feip',
        sku => 'Standard')

Create a load balancer entity.
LB is mostly "just" a "group" definition
to link back-end and front-end resources (usually an IP)

SKU Standard (and not Basic) is needed to get some Metrics

=over 8

=item B<resource_group> - existing resource group where to create lb

=item B<name> - load balancer name

=item B<vnet> - existing Virtual network name where to create LB in

=item B<snet> - existing Subnet network name where to create LB in

=item B<backend> - name to assign to created backend pool

=item B<frontend_ip_name> - name to assign to created frontend ip, will be reused in "az network lb rule create"

=item B<sku> - default Basic

=item B<fip> - optionally add --private-ip-address

=back
=cut

sub az_network_lb_create {
    my (%args) = @_;
    foreach (qw(resource_group name vnet snet backend frontend_ip_name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    $args{sku} //= 'Basic';
    my $fip_cmd = '';
    if ($args{fip}) {
        croak "Invalid IP address fip:$args{fip}"
          unless ($args{fip} =~ /^[1-9]{1}[0-9]{0,2}\.(0|[1-9]{1,3})\.(0|[1-9]{1,3})\.[1-9]{1}[0-9]{0,2}$/);
        $fip_cmd = "--private-ip-address $args{fip}";
    }

    my $az_cmd = join(' ', 'az network lb create',
        '--resource-group', $args{resource_group},
        '-n', $args{name},
        '--sku', $args{sku},
        '--vnet-name', $args{vnet},
        '--subnet', $args{snet},
        '--backend-pool-name', $args{backend},
        '--frontend-ip-name', $args{frontend_ip_name},
        $fip_cmd);
    assert_script_run($az_cmd);
}

=head2 az_network_lb_probe_create

    az_network_lb_probe_create(
        resource_group => 'openqa-rg',
        lb_name => 'openqa-lb',
        name => 'openqa-lb-hp',
        port => '4242',
        protocol => 'Udp',
        )

Create a load balancer health probe.

=over 5

=item B<resource_group> - existing resource group where to create lb

=item B<lb_name> - existing load balancer name

=item B<name> - name for the new health probe

=item B<port> - port number monitored by the health probe

=item B<protocol> - protocol for the health probe. Default Tcp

=back
=cut

sub az_network_lb_probe_create {
    my (%args) = @_;
    foreach (qw(resource_group lb_name name port)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{protocol} //= 'Tcp';

    my $az_cmd = join(' ', 'az network lb probe create',
        '--resource-group', $args{resource_group},
        '--lb-name', $args{lb_name},
        '--name', $args{name},
        '--port', $args{port},
        '--protocol', $args{protocol},
        '--interval 5',
        '--probe-threshold 2');
    assert_script_run($az_cmd);
}

=head2 az_network_lb_rule_create

    az_network_lb_rule_create(
        resource_group => 'openqa-rg',
        lb_name => 'openqa-lb',
        hp_name => 'openqa-hb',
        frontend_ip => 'openqa-fe',
        backend => 'openqa-be',
        name => 'openqa-lb-rule',
        port => '80'
        )

Configure the load balancer behavior.

=over 8

=item B<resource_group> - existing resource group where to create lb

=item B<lb_name> - existing load balancer name

=item B<hp_name> - existing load balancer health probe name

=item B<frontend_ip> - existing load balancer front end IP name

=item B<backend> - existing load balancer back end pool name

=item B<name> - name for the new load balancer rule

=item B<port> - port mapped between the frontend and the backend. This poor Perl wrapper map them 1:1

=item B<protocol> - protocol for the load balancer rule. Default Tcp

=back
=cut

sub az_network_lb_rule_create {
    my (%args) = @_;
    foreach (qw(resource_group lb_name hp_name frontend_ip backend name port)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{protocol} //= 'Tcp';

    my $az_cmd = join(' ', 'az network lb rule create',
        '--resource-group', $args{resource_group},
        '--lb-name', $args{lb_name},
        '--probe-name', $args{hp_name},
        '--name', $args{name},
        '--protocol', $args{protocol},
        '--frontend-ip-name', $args{frontend_ip}, '--frontend-port', $args{port},
        '--backend-pool-name', $args{backend}, '--backend-port', $args{port},
        # These two are from qe-sap-deployment
        #  - idle_timeout_in_minutes        = 30
        #  - enable_floating_ip             = "true"
        '--idle-timeout 30 --enable-floating-ip 1');
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

=head2 az_vm_name_get

    my $ret = az_vm_name_get(resource_group => 'openqa-rg');

Get the name of all existing VMs within a Resource groups

=over 1

=item B<resource_group> - existing resource group where to create the network

=back
=cut

sub az_vm_name_get {
    my (%args) = @_;
    croak("Argument < resource_group > missing") unless $args{resource_group};
    my $az_cmd = join(' ',
        'az vm list',
        "-g $args{resource_group}",
        '--query "[].name"',
        '-o json');
    return decode_json(script_output($az_cmd));
}

=head2 az_vm_instance_view_get

    my $res = az_vm_instance_view_get(
        resource_group => 'openqa-rg',
        name => 'openqa-vm')

Get some details of a specific VM

Json output looks like:

[
  "PowerState/running",
  "VM running"
]

=over 2

=item B<resource_group> - existing resource group where to create the VM

=item B<name> - name of an existing virtual machine

=back
=cut

sub az_vm_instance_view_get {
    my (%args) = @_;
    foreach (qw(resource_group name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    my $az_cmd = join(' ',
        'az vm get-instance-view',
        '--name', $args{name},
        '--resource-group', $args{resource_group},
        '--query "instanceView.statuses[1].[code,displayStatus]"');
    return decode_json(script_output($az_cmd));
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

Wait cloud-init completion on a running VM

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
    assert_script_run($az_cmd, timeout => ($args{timeout} + 10));
}

=head2 az_nic_id_get

    my $nic_id = az_nic_id_get(
        resource_group => 'openqa-rg',
        name => 'openqa-vm')

Get the NIC ID of the first NIC of a given VM

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

Get the NIC data from NIC ID

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

Get the NIC name from NIC ID

=over 1

=item B<nic_id> - existing NIC ID (eg. from az_nic_id_get)

=back
=cut

sub az_nic_name_get {
    my (%args) = @_;
    croak('Argument < nic_id > missing') unless $args{nic_id};
    return az_nic_get(nic_id => $args{nic_id}, filter => 'name');
}

=head2 az_ipconfig_name_get

    my $ipconfig_name = az_ipconfig_name_get(
        resource_group => 'openqa-rg',
        name => 'openqa-vm')

Get the name of the first IpConfig of a NIC from a NIC ID

=over 1

=item B<nic_id> - existing NIC ID (eg. from az_nic_id_get)

=back
=cut

sub az_ipconfig_name_get {
    my (%args) = @_;
    croak('Argument < nic_id > missing') unless $args{nic_id};

    return az_nic_get(nic_id => $args{nic_id}, filter => 'ipConfigurations[0].name');
}

=head2 az_ipconfig_update

    az_ipconfig_update(
        resource_group => 'openqa-rg',
        ipconfig_name => 'openqa-ipconfig',
        nic_name => 'openqa-nic',
        ip => '192.168.0.42')

Change the IpConfig to use a static IP

=over 4

=item B<resource_group> - existing resource group

=item B<ipconfig_name> - existing IP configuration NAME (eg. from az_ipconfig_name_get)

=item B<nic_name> - existing NIC NAME (eg. from az_nic_name_get)

=item B<ip> - IPv4 address to assign as static IP

=back
=cut

sub az_ipconfig_update {
    my (%args) = @_;
    foreach (qw(resource_group ipconfig_name nic_name ip)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $az_cmd = join(' ', 'az network nic ip-config update',
        '--resource-group', $args{resource_group},
        '--name', $args{ipconfig_name},
        '--nic-name', $args{nic_name},
        '--private-ip-address', $args{ip});
    assert_script_run($az_cmd, timeout => 900);
}

=head2 az_ipconfig_pool_add

    az_ipconfig_pool_add(
        resource_group => 'openqa-rg',
        lb_name => 'openqa-lb',
        address_pool => 'openqa-addr-pool',
        ipconfig_name => 'openqa-ipconfig',
        nic_name => 'openqa-nic')

Add the IpConfig to a LB address pool

=over 3

=item B<resource_group> - existing resource group

=item B<lb_name> - existing Load balancer NAME

=item B<address_pool> - existing Load balancer address pool name

=back
=cut

sub az_ipconfig_pool_add {
    my (%args) = @_;
    foreach (qw(resource_group lb_name address_pool ipconfig_name nic_name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $az_cmd = join(' ', 'az network nic ip-config address-pool add',
        '--resource-group', $args{resource_group},
        '--lb-name', $args{lb_name},
        '--address-pool', $args{address_pool},
        '--ip-config-name', $args{ipconfig_name},
        '--nic-name', $args{nic_name});
    assert_script_run($az_cmd);
}
=head2 az_network_vnet_list

    az_network_vnet_list( resource_group => 'openqa-rg' )

    Get list of virtual networks belonging to resource group. Returns ARRAYREF.

=over 2

=item B<resource_group> - existing resource group name

=back
=cut

sub az_network_vnet_list {
    my (%args) = @_;
    croak "Missing mandatory argument: '\$args{resource_group}'" unless $args{resource_group};
    my $cmd = "az network vnet list --resource-group $args{resource_group} --query \"[].name\" -o json";
    my $vnet_list = decode_json(script_output($cmd));
    return $vnet_list;
}

=head2 az_network_vnet_subnet_list

    az_network_vnet_subnet_list( resource_group => 'openqa-rg', vnet_name => 'rg-vnet' )

    Get list of subnets belonging to vnet inside resource group. Returns ARRAYREF.

=over 2

=item B<resource_group> - existing resource group name

=item B<vnet_name> - existing vnet name

=back
=cut

sub az_network_vnet_subnet_list {
    my (%args) = @_;
    croak "Missing mandatory argument: '\$args{resource_group}'" unless $args{resource_group};
    croak "Missing mandatory argument: '\$args{vnet_name}'" unless $args{vnet_name};

    my $cmd = "az network vnet subnet list --resource-group $args{resource_group} --vnet-name $args{vnet_name} --query \"[].name\" -o json";
    my $subnet_list = decode_json(script_output($cmd));
    return $subnet_list;
}

=head2 az_network_nat_gateway_create

    az_network_nat_gateway_create( resource_group => 'openqa-rg', gateway_name=>'', public_ip=>'' )

    Create new NAT gateway, returns gateway name

=over 2

=item B<resource_group> - existing resource group name

=item B<gateway_name> - name for newly created nat gateway

=item B<public_ip> - exisitng public IP resource name to associate with gateway

=item B<timeout> - Optional command timeout override

=back
=cut

sub az_network_nat_gateway_create {
    my (%args) = @_;
    croak "Missing mandatory argument: '\$args{resource_group}'" unless $args{resource_group};
    croak "Missing mandatory argument: '\$args{gateway_name}'" unless $args{gateway_name};
    croak "Missing mandatory argument: '\$args{public_ip}'" unless $args{public_ip};

    my $cmd = "az network nat gateway create --resource-group $args{resource_group} --name $args{gateway_name} --public-ip-addresses $args{public_ip}";
    record_info('NAT create', "Creating NAT gateway '$args{gateway_name}' for public IP ''$args{public_ip}\nCMD: '$cmd'");
    assert_script_run($cmd, $args{timeout});

    return $args{gateway_name};
}

=head2 az_network_nat_gateway_delete

    az_network_nat_gateway_delete( resource_group => 'openqa-rg', gateway_name=>'', public_ip=>'' )

    Create new NAT gateway, returns gateway name

=over 2

=item B<resource_group> - existing resource group name

=item B<gateway_name> - name for newly created nat gateway

=item B<timeout> - Optional command timeout override

=back
=cut

sub az_network_nat_gateway_delete {
    my (%args) = @_;
    croak "Missing mandatory argument: '\$args{resource_group}'" unless $args{resource_group};
    croak "Missing mandatory argument: '\$args{gateway_name}'" unless $args{gateway_name};

    my $cmd = "az network nat gateway delete --resource-group $args{resource_group} --name $args{gateway_name}";
    record_info('NAT delete', "Deleting NAT gateway '$args{gateway_name}'\nCMD: '$cmd'");
    assert_script_run($cmd, $args{timeout});
}

=head2 az_network_vnet_subnet_update

    az_network_vnet_subnet_update( resource_group => 'openqa-rg', gateway_name=>'', public_ip=>'' )

    Create new NAT gateway, returns gateway name

=over 2

=item B<resource_group> - existing resource group name

=item B<gateway_name> - name for newly created nat gateway

=item B<subnet_name> - resource name for existing subnet inside resource group

=item B<vnet_name> - exisitng vnet resource name to associate with gateway

=back
=cut

sub az_network_vnet_subnet_update {
    my (%args) = @_;
    foreach ('resource_group', 'subnet_name', 'vnet_name', 'gateway_name') {
        croak "Missing mandatory argument: '$_'" unless $args{$_};
    }

    my $cmd = "az network vnet subnet update --resource-group $args{resource_group} --name $args{subnet_name} --vnet-name $args{vnet_name} --nat-gateway $args{gateway_name}";
    record_info('NAT update', "Associating NAT gateway '$args{gateway_name}' with subnet '$args{subnet_name}'\nCMD: '$cmd'");
    assert_script_run($cmd);
}
