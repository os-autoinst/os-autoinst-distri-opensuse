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
use Regexp::Common qw(net);
use NetAddr::IP;
use utils qw(write_sut_file);


=head1 SYNOPSIS

Library to compose and run Azure cli commands
=cut

our @EXPORT = qw(
  az_version
  az_group_create
  az_group_name_get
  az_group_delete
  az_network_vnet_create
  az_network_vnet_get
  az_network_vnet_subnet_update
  az_network_nsg_create
  az_network_nsg_rule_create
  az_network_publicip_create
  az_network_publicip_get
  az_network_nat_gateway_create
  az_network_lb_create
  az_network_lb_probe_create
  az_network_lb_rule_create
  az_vm_as_create
  az_img_from_vhd_create
  az_vm_create
  az_vm_list
  az_vm_openport
  az_vm_wait_cloudinit
  az_vm_instance_view_get
  az_vm_wait_running
  az_vm_diagnostic_log_enable
  az_vm_diagnostic_log_get
  az_nic_id_get
  az_nic_name_get
  az_ipconfig_name_get
  az_ipconfig_update
  az_ipconfig_delete
  az_ipconfig_pool_add
  az_storage_account_create
  az_storage_blob_list
  az_storage_blob_upload
  az_storage_blob_update
  az_storage_blob_lease_acquire
  az_network_peering_create
  az_network_peering_list
  az_network_peering_delete
  az_disk_create
  az_resource_delete
  az_resource_list
  az_validate_uuid_pattern
  az_keyvault_list
  az_keyvault_secret_list
  az_keyvault_secret_show
);


=head2 az_version

    az_version();

Print the version of the az cli available on system
=cut

sub az_version {
    assert_script_run('az --version');
}


=head2 az_group_create

    az_group_create(
        name => 'openqa-rg',
        region => 'westeurope');

Create an Azure resource group in a specific region

=over

=item B<name> - full name of the resource group

=item B<region> - Azure region where to create the resource group

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

Get the name of all existing Resource Group in the current subscription

=cut

sub az_group_name_get {
    my $az_cmd = join(' ',
        'az group list',
        '--query "[].name"',
        '-o json');
    return decode_json(script_output($az_cmd));
}

=head2 az_group_delete

    az_group_delete( name => 'openqa-rg' );

Delete a resource group with a specific name

=over

=item B<name> - full name of the resource group

=item B<timeout> - timeout, default 60

=back
=cut

sub az_group_delete {
    my (%args) = @_;
    croak("Argument < name > missing") unless $args{name};
    $args{timeout} //= 60;
    my $az_cmd = join(' ',
        'az group delete',
        '--name', $args{name}, '-y');
    assert_script_run($az_cmd, timeout => $args{timeout});
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

=over

=item B<resource_group> - existing resource group where to create the network

=item B<region> - Azure region where to create the VNET

=item B<vnet> - name of the virtual network

=item B<snet> - name of the subnet

=item B<address_prefixes> - virtual network ip address space. Default 192.168.0.0/16

=item B<subnet_prefixes> - subnet ip address space. Default 192.168.0.0/24

=back
=cut

sub az_network_vnet_create {
    my (%args) = @_;
    foreach (qw(resource_group region vnet)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    # Only set default value for ranges if the caller
    # require to also create the subnet
    if ($args{snet}) {
        $args{address_prefixes} //= '192.168.0.0/32';
        $args{subnet_prefixes} //= '192.168.0.0/32';
    }

    # Validate and eventually fix the ranges
    my %ranges;
    foreach (qw(address_prefixes subnet_prefixes)) {
        if ($args{$_}) {
            $ranges{$_} = NetAddr::IP->new($args{$_}) or croak "Invalid IP range $args{$_} in $_";
        }
    }

    my @az_cmd_list = ('az network vnet create');
    push @az_cmd_list, '--resource-group', $args{resource_group};
    push @az_cmd_list, '--location', $args{region};
    push @az_cmd_list, '--name', $args{vnet};
    if ($args{address_prefixes}) {
        push @az_cmd_list, '--address-prefixes', $ranges{address_prefixes};
    }
    if ($args{snet}) {
        push @az_cmd_list, '--subnet-name', $args{snet};
        push @az_cmd_list, '--subnet-prefixes', $ranges{subnet_prefixes};
    }
    assert_script_run(join(' ', @az_cmd_list));
}

=head2 az_network_vnet_subnet_update

    az_network_vnet_subnet_update(
        resource_group => 'openqa-rg',
        vnet => 'openqa-vnet',
        snet => 'openqa-subnet',
        nat_gateway => 'openqa-nat')

Update a Subnet

=over

=item B<resource_group> - existing resource group where to create the network

=item B<vnet> - name of the virtual network

=item B<snet> - name of the subnet

=item B<nat_gateway> - optional argument, if provided the update is about
                       associating a Subnet th a NAT gateway

=back
=cut

sub az_network_vnet_subnet_update {
    my (%args) = @_;
    foreach (qw(resource_group snet vnet)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my @az_cmd_list = ('az network vnet subnet update');
    push @az_cmd_list, '--resource-group', $args{resource_group};
    push @az_cmd_list, '--vnet-name', $args{vnet};
    push @az_cmd_list, '--name', $args{snet};

    # at the moment nat_gateway is optional,
    # so without this argument the command is
    # executed anyway, but probably it will not do so much.
    if ($args{nat_gateway}) {
        push @az_cmd_list, '--nat-gateway', $args{nat_gateway};
    }
    assert_script_run(join(' ', @az_cmd_list));
}

=head3 az_network_vnet_get

    my $res = az_network_vnet_get(resource_group => 'openqa-rg')

Return the output of az network vnet list

=over

=item B<resource_group> - resource group name to query

=item B<query> - valid jmespath https://jmespath.org/

=back
=cut

sub az_network_vnet_get {
    my (%args) = @_;
    croak("Argument < resource_group > missing") unless $args{resource_group};
    $args{query} //= '[].name';

    my $az_cmd = join(' ', 'az network vnet list',
        '-g', $args{resource_group},
        "--query \"$args{query}\"",
        '-o json');
    return decode_json(script_output($az_cmd));
}

=head2 az_network_nsg_create

    az_network_nsg_create(
        resource_group => 'openqa-rg',
        name => 'openqa-nsg')

Create a network security group

=over

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

=over

=item B<resource_group> - existing resource group where to create the NSG rule

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

=over

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

=head2 az_network_publicip_get

    az_network_publicip_get(
        resource_group => 'openqa-rg',
        name => 'openqa-pip')

Return an IPv4 public IP address from its name

=over

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

=head2 az_network_nat_gateway_create

    az_network_nat_gateway_create(
        resource_group => 'openqa-rg',
        region => 'westeurope',
        name => 'openqa-nat-gateway',
        public_ip => 'openqa-pubip')

Create a NAT Gateway

=over

=item B<resource_group> - existing resource group where to create the NAT Gateway

=item B<region> - Azure region where to create the NAT Gateway

=item B<name> - NAT Gateway resource name

=item B<public_ip> - add to the NAT Gateway a public IP

=back
=cut

sub az_network_nat_gateway_create {
    my (%args) = @_;
    foreach (qw(resource_group region name public_ip)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $az_cmd = join(' ', 'az network nat gateway create',
        '--resource-group', $args{resource_group},
        '--location', $args{region},
        '--name', $args{name},
        '--public-ip-addresses', $args{public_ip},
        '--idle-timeout 10');
    assert_script_run($az_cmd);
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

=over

=item B<resource_group> - existing resource group where to create lb

=item B<name> - load balancer name

=item B<vnet> - existing Virtual network name where to create LB in

=item B<snet> - existing Subnet network name where to create LB in

=item B<backend> - name to assign to created backend pool

=item B<frontend_ip_name> - name to assign to created frontend ip,
                            will be reused in "az network lb rule create"

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
        croak "Not a valid ip addr: $args{fip}" unless grep /^$RE{net}{IPv4}$/, $args{fip};
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

=over

=item B<resource_group> - existing resource group where to create lb probe

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

=over

=item B<resource_group> - existing resource group where to create lb rule

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
        region => 'westeurope',
        name => 'openqa-as',
        fault_count => 2)

Create an availability set. Later on VM can be assigned to it.

=over

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

=head2 az_img_from_vhd_create

    az_img_from_vhd_create(resource_group => $rg, name => $name, source => $uploaded_vhd_url);

Create an image out of a .vhd disk in Azure storage.

=over

=item B<resource_group> - existing resource group

=item B<name> - NAME of the created image

=item B<source> - URI of the vhd disk from which the image will be created

=back
=cut

sub az_img_from_vhd_create {
    my (%args) = @_;
    foreach (qw(resource_group name source)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    my $az_cmd = join(' ', 'az image create',
        '--resource-group', $args{resource_group},
        '-n', $args{name},
        '--os-type', 'linux',
        '--source', $args{source});
    assert_script_run($az_cmd, timeout => 600);
}

=head2 az_vm_create

    az_vm_create(
        resource_group => 'openqa-rg',
        region => 'westeurope',
        name => 'openqa-vm',
        image => 'SUSE:sles-sap-15-sp5:gen2:latest')

Create a virtual machine

=over

=item B<resource_group> - existing resource group where to create the VM

=item B<region> - optional region where to create the VM

=item B<name> - virtual machine name

=item B<image> - OS image name

=item B<vnet> - optional name of the Virtual Network where to place the VM

=item B<snet> - optional name of the SubNet where to connect the VM

=item B<size> - VM size, default Standard_B1s

=item B<availability_set> - optional inclusion in an availability set

=item B<username> - optional admin username

=item B<nsg> - optional inclusion in an network security group

=item B<nic> - optional add to the VM a NIC created separately with 'az network nic create'

=item B<public_ip> - optional add to the VM a public IP. Value like "" is a valid one and
                     is not the same as not including the argument at all.

=item B<custom_data> - optional provide a cloud-init script file

=item B<ssh_pubkey> - optional inclusion in an availability set,
          if missing the command is configured to generate one

=item B<security_type> - is used force a specific value for '--security-type'

=back
=cut

sub az_vm_create {
    my (%args) = @_;
    foreach (qw(resource_group name image)) {
        croak("Argument < $_ > missing") unless $args{$_}; }


    my @vm_create = ('az vm create');

    push @vm_create, '--resource-group', $args{resource_group};
    push @vm_create, '-n', $args{name};
    push @vm_create, '--image', $args{image};
    push @vm_create, '--public-ip-address';
    push @vm_create, $args{public_ip} ? $args{public_ip} : '""';

    $args{size} //= 'Standard_B1s';
    push @vm_create, '--size', $args{size};

    push @vm_create, '-l', $args{region} if $args{region};
    push @vm_create, '--availability-set', $args{availability_set} if $args{availability_set};

    push @vm_create, '--admin-username', $args{username} if $args{username};
    push @vm_create, '--nsg', $args{nsg} if $args{nsg};
    push @vm_create, '--custom-data', $args{custom_data} if $args{custom_data};
    push @vm_create, '--nics', $args{nic} if $args{nic};
    push @vm_create, '--vnet-name', $args{vnet} if $args{vnet};
    push @vm_create, '--subnet', $args{snet} if $args{snet};
    push @vm_create, '--security-type', $args{security_type} if $args{security_type};
    if ($args{ssh_pubkey}) {
        push @vm_create, '--ssh-key-values', $args{ssh_pubkey};
    } else {
        push @vm_create, '--authentication-type ssh --generate-ssh-keys';
    }

    assert_script_run(join(' ', @vm_create), timeout => 900);
}

=head2 az_vm_list

    my $ret = az_vm_list(resource_group => 'openqa-rg', query => '[].name');

Get the info from all existing VMs within a Resource Group
Return a decoded json hash according to the provided jmespath query

=over

=item B<resource_group> - existing resource group where to search for VMs

=item B<query> - valid jmespath https://jmespath.org/

=back
=cut

sub az_vm_list {
    my (%args) = @_;
    croak("Argument < resource_group > missing") unless $args{resource_group};
    $args{query} //= '[].name';

    my $az_cmd = join(' ',
        'az vm list',
        "-g $args{resource_group}",
        "--query \"$args{query}\"",
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

=over

=item B<resource_group> - existing resource group where to look for a specific VM

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

=head2 az_vm_wait_running

    my $res = az_vm_wait_running(
        resource_group => 'openqa-rg',
        name => 'openqa-vm',
        timeout => 300)

Get the VM state until status looks like:

[
  "PowerState/running",
  "VM running"
]

or reach timeout.

Polling frequency is dynamically calculated based on the timeout.

It returns the total ammount of time spent waiting or function kills the test on timeout.

=over

=item B<resource_group> - existing resource group where to look for a specific VM

=item B<name> - name of an existing virtual machine

=item B<timeout> - optional, default 300

=back
=cut

sub az_vm_wait_running {
    my (%args) = @_;
    foreach (qw(resource_group name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{timeout} //= 300;

    # calculate a proper sleep time to be used at the end of each retry loop
    #  - if the overall timeout is short then sleeps for
    #    half of the timeout: it result in re-trying two times
    #  - if the overall timeout is long then sleeps for
    #    a fixed amount of 30secs
    my $sleep_time = $args{timeout} < 60 ? int($args{timeout} / 2) : 30;
    my $res;
    my $count;
    my $start_time = time();
    while (time() - $start_time <= $args{timeout}) {
        $res = az_vm_instance_view_get(
            resource_group => $args{resource_group},
            name => $args{name});
        # Expected return is
        # [ "PowerState/running", "VM running" ]
        $count = grep(/running/, @$res);
        return (time() - $start_time) if ($count eq 2);
        sleep $sleep_time;
    }
    die "VM not running after " . (time() - $start_time) . " seconds";
}

=head2 az_vm_openport

    az_vm_openport(
        resource_group => 'openqa-rg',
        name => 'openqa-vm',
        port => 80)

Open a port on an existing VM

=over

=item B<resource_group> - existing resource group where to search for a specific VM

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

=over

=item B<resource_group> - existing resource group where to search for a specific VM

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
    assert_script_run($az_cmd, timeout => ($args{timeout} + 300));
}

=head2 az_nic_id_get

    my $nic_id = az_nic_id_get(
        resource_group => 'openqa-rg',
        name => 'openqa-vm')

Get the NIC ID of the first NIC of a given VM

=over

=item B<resource_group> - existing resource group where to search for a specific NIC

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

=over

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

=over

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

=over

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

=over

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

    croak "Not a valid ip addr: $args{ip}" unless grep /^$RE{net}{IPv4}$/, $args{ip};

    my $az_cmd = join(' ', 'az network nic ip-config update',
        '--resource-group', $args{resource_group},
        '--name', $args{ipconfig_name},
        '--nic-name', $args{nic_name},
        '--private-ip-address', $args{ip});
    assert_script_run($az_cmd, timeout => 900);
}

=head2 az_ipconfig_delete

    az_ipconfig_delete(
        resource_group => 'openqa-rg',
        ipconfig_name => 'openqa-ipconfig',
        nic_name => 'openqa-nic')

Delete a specific IpConfig to use a static IP

=over

=item B<resource_group> - existing resource group

=item B<ipconfig_name> - existing IP configuration NAME (eg. from az_ipconfig_name_get)

=item B<nic_name> - existing NIC NAME (eg. from az_nic_name_get)

=back
=cut

sub az_ipconfig_delete {
    my (%args) = @_;
    foreach (qw(resource_group ipconfig_name nic_name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $az_cmd = join(' ', 'az network nic ip-config delete',
        '--resource-group', $args{resource_group},
        '--name', $args{ipconfig_name},
        '--nic-name', $args{nic_name});
    assert_script_run($az_cmd);
}

=head2 az_ipconfig_pool_add

    az_ipconfig_pool_add(
        resource_group => 'openqa-rg',
        lb_name => 'openqa-lb',
        address_pool => 'openqa-addr-pool',
        ipconfig_name => 'openqa-ipconfig',
        nic_name => 'openqa-nic')

Add the IpConfig to a LB address pool

=over

=item B<resource_group> - existing resource group

=item B<lb_name> - existing Load balancer NAME

=item B<address_pool> - existing Load balancer address pool name

=item B<timeout> - timeout, default 60

=back
=cut

sub az_ipconfig_pool_add {
    my (%args) = @_;
    foreach (qw(resource_group lb_name address_pool ipconfig_name nic_name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{timeout} //= 60;

    my $az_cmd = join(' ', 'az network nic ip-config address-pool add',
        '--resource-group', $args{resource_group},
        '--lb-name', $args{lb_name},
        '--address-pool', $args{address_pool},
        '--ip-config-name', $args{ipconfig_name},
        '--nic-name', $args{nic_name});
    assert_script_run($az_cmd, timeout => $args{timeout});
}

=head2 az_vm_diagnostic_log_enable

    az_vm_diagnostic_log_enable(resource_group => 'openqa-rg',
                                storage_account => 'openqasa',
                                vm_name => 'openqa-vm')

Enable diagnostic log for a specific VM

=over

=item B<resource_group> - existing resource group where to search for a specific VM

=item B<storage_account> - existing storage account

=item B<vm_name> - existing VM name

=back
=cut

sub az_vm_diagnostic_log_enable {
    my (%args) = @_;
    foreach (qw(resource_group storage_account vm_name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $az_cmd = join(' ', 'az storage account show',
        '-g', $args{resource_group},
        '--name', $args{storage_account},
        '--query "primaryEndpoints.blob"',
        '-o tsv');
    my $endpoint = script_output($az_cmd);

    $az_cmd = join(' ', 'az vm boot-diagnostics enable',
        '--name', $args{vm_name},
        '--resource-group', $args{resource_group},
        '--storage', $endpoint);
    assert_script_run($az_cmd);
}


=head2 az_vm_diagnostic_log_get

    my $list_of_logs = az_vm_diagnostic_log_get(resource_group => 'openqa-rg')

Call `az vm boot-diagnostics json` for each running VM in the
resource group associated to this openQA job

Return a list of diagnostic file paths on the JumpHost

=over

=item B<resource_group> - existing resource group where to search for a specific VM

=back
=cut

sub az_vm_diagnostic_log_get {
    my (%args) = @_;
    croak("Argument < resource_group > missing") unless $args{resource_group};

    my @diagnostic_log_files;
    my $vm_data = az_vm_list(resource_group => $args{resource_group}, query => '[].{id:id,name:name}');
    my $az_get_logs_cmd = 'az vm boot-diagnostics get-boot-log --ids';
    foreach (@{$vm_data}) {
        my $boot_diagnostics_log = '/tmp/boot-diagnostics_' . $_->{name} . '.txt';
        push @diagnostic_log_files, $boot_diagnostics_log unless
          script_run(join(' ', $az_get_logs_cmd, $_->{id}, '|&', 'tee', $boot_diagnostics_log));
    }
    return @diagnostic_log_files;
}

=head2 az_storage_account_create

    az_storage_account_create(
        resource_group => 'openqa-rg',
        region => 'westeurope'
        name => 'openqasa')

Create a storage account

=over

=item B<resource_group> - existing resource group where to create the storage account

=item B<region> - Azure region where to create the storage

=item B<name> - name for the storage account to be created. Storage account name must be
                between 3 and 24 characters in length and use numbers and lower-case letters only.

=back
=cut

sub az_storage_account_create {
    my (%args) = @_;
    foreach (qw(resource_group region name)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $az_cmd = join(' ', 'az storage account create',
        '--resource-group', $args{resource_group},
        '--location', $args{region},
        '-n', $args{name});
    assert_script_run($az_cmd);
}

=head2 az_network_peering_create

    az_network_peering_create(
        name => 'openqa-fromVNET-toVNET',
        source_rg => 'openqa-rg',
        source_vnet => 'openqa-this-vnet',
        target_rg => 'openqa-rg',
        target_vnet => 'openqa-this-vnet')

Create network peering

=over

=item B<name> - NAME for the network peering to create

=item B<source_rg> - existing resource group that contain vnet source of the peering

=item B<source_vnet> - existing vnet in source_rg, used as source of the peering

=item B<target_rg> - existing resource group that contain vnet target of the peering

=item B<target_vnet> - existing vnet in target_rg, used as target of the peering

=back
=cut

sub az_network_peering_create {
    my (%args) = @_;
    foreach (qw(name source_rg source_vnet target_rg target_vnet)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $az_cmd = join(' ', 'az network vnet show',
        '--query id',
        '--output tsv',
        '--resource-group', $args{target_rg},
        '--name', $args{target_vnet});

    my $target_vnet_id = script_output($az_cmd);

    $az_cmd = join(' ', 'az network vnet peering create',
        '--name', $args{name},
        '--resource-group', $args{source_rg},
        '--vnet-name', $args{source_vnet},
        '--remote-vnet', $target_vnet_id,
        '--allow-vnet-access',
        '--output table');
    assert_script_run($az_cmd);
}

=head2 az_network_peering_list

    my $res = az_network_peering_list(
        resource_group => 'openqa-rg',
        vnet => 'openqa-this-vnet' [, query=>'[].name'])

Return HASH representing existing net peering

=over

=item B<resource_group> - existing resource group that contain vnet source of the peering

=item B<vnet> - existing vnet in resource_group, used as source of the peering

=item B<query> - valid jmespath https://jmespath.org/

=back
=cut

sub az_network_peering_list {
    my (%args) = @_;
    foreach (qw(resource_group vnet)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{query} //= '[].name';

    my $az_cmd = join(' ', 'az network vnet peering list',
        '--resource-group', $args{resource_group},
        '--vnet-name', $args{vnet},
        "--query \"$args{query}\"",
        '-o json');
    return decode_json(script_output($az_cmd));
}

=head2 az_network_peering_delete

    az_network_peering_delete(
        name => 'openqa-fromVNET-toVNET',
        resource_group => 'openqa-rg',
        vnet => 'openqa-this-vnet')

Delete a specific network peering

=over

=item B<name> - name of the existing the network peering to delete

=item B<resource_group> - existing resource group that contain vnet source of the peering

=item B<vnet> - existing vnet in resource_group, used as source of the peering

=back
=cut

sub az_network_peering_delete {
    my (%args) = @_;
    foreach (qw(name resource_group vnet)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $az_cmd = join(' ', 'az network vnet peering delete',
        '--name', $args{name},
        '--resource-group', $args{resource_group},
        '--vnet-name', $args{vnet});
    assert_script_run($az_cmd);
}

=head2 az_disk_create

    az_disk_create(resource_group=>$resource_group, name=>$name
        [, size_gb=>60, source=$source, tags="tag1=value1 tag2=value2"]);


Creates new disk device either by specifying B<size_gb> or by cloning another disk device using argument B<source>.
Arguments B<size_gb> and B<source> are mutually exclusive.

=over

=item B<name> New disk name

=item B<resource_group> Existing resource group name.

=item B<source> Create disk by cloning snapshot

=item B<size_gb> New disk size

=item B<tags> Additional tags to add to the disk resource. key=value pairs must be separated by empty space.
    Example: az_disk_create(tags=>"some_tag=some_value another_tag=another_value")

=back
=cut

sub az_disk_create {
    my (%args) = @_;
    foreach ('resource_group', 'name') { croak("Argument < $_ > missing") unless $args{$_}; }
    croak "Arguments 'size_gb' and 'source' are mutually exclusive" if $args{size_gb} and $args{source};
    croak "Argument 'size_gb' or 'source' has to be specified" unless $args{size_gb} or $args{source};

    my @az_command = ('az disk create',
        "--resource-group $args{resource_group}",
        "--name $args{name}",
    );
    push @az_command, "--source $args{source}" if $args{source};
    push @az_command, "--size-gb $args{size_gb}" if $args{size_gb};
    push @az_command, "--tags $args{tags}" if $args{tags};
    assert_script_run(join(' ', @az_command));
}

=head2 az_resource_delete

    az_resource_delete(resource_group=>$resource_group, name=>$name);

Deletes resource from specified resource group. Single resource can be deleted by specifying B<name> or list of resource IDs
delimited by empty space using argument B<ids>.
Arguments B<name> and B<ids> are mutually exclusive.
Function returns `az` command exit code.

=over

=item B<resource_group> Existing resource group name.

=item B<name> Name of the resource to delete

=item B<ids> list of resource IDs to delete

=item B<verbose> Turn on az command verbosity. Default: off

=item B<timeout> Timeout for az command. Default: 60

=back
=cut

sub az_resource_delete {
    my (%args) = @_;
    croak "Mandatory argument 'resource_group' missing" unless $args{resource_group};
    croak "Arguments 'name' and 'ids' are mutually exclusive" if $args{ids} and $args{name};
    croak "Argument 'name' or 'ids' has to be specified" unless $args{ids} or $args{name};
    $args{timeout} //= 60;
    my $temp_script_file = '/tmp/' . sprintf("%010x", int(rand(0xffffffff))) . '-az_resource_delete.sh';
    my @az_command = ('az resource delete',
        "--resource-group $args{resource_group}"
    );
    push @az_command, "--name $args{name}" if $args{name};
    push @az_command, "--ids $args{ids}" if $args{ids};
    push @az_command, "--verbose" if $args{verbose};

    # az cli command has to be run in a shell script. Problem with `script_run` api call is that it does not handle
    # long commands very well. If the command is too long, internal `wait_serial` call might fail.
    write_sut_file($temp_script_file, join(' ', @az_command));
    assert_script_run("chmod +x $temp_script_file");
    my $rc = script_run("/usr/bin/bash -x $temp_script_file", timeout => $args{timeout});
    assert_script_run("rm $temp_script_file");
    return $rc;
}

=head2 az_resource_list

    az_resource_list([resource_group=>$resource_group, query=>$query, output=>$output]);

Lists existing az resources based on arguments provided. Calling function without any argument returns full information
from all existing resource groups.
Returns decoded json structure if json format is requested, otherwise whole output is a string.

=over

=item B<resource_group> Existing resource group name.

=item B<query> Jmespath query

=back
=cut

sub az_resource_list {
    my (%args) = @_;
    my @az_command = ('az resource list');
    push(@az_command, "--resource-group $args{resource_group}") if $args{resource_group};
    push(@az_command, "--query \"$args{query}\"") if $args{query};
    push(@az_command, '--output json');

    return (decode_json(script_output(join(' ', @az_command))));
}

=head2 az_validate_uuid_pattern

    az_validate_uuid_pattern( uuid => $uuid_string )

    Function checks input string against uuid pattern
    which is commonly used as an identifier for Azure resources.
    returns uuid (true) on match, 0 (false) on mismatch.

=over

=item B<uuid> UUID string to test.

=back
=cut

sub az_validate_uuid_pattern {
    my (%args) = @_;
    croak "Mandatory argument 'uuid' missing" unless $args{uuid};
    my $pattern = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
    return $args{uuid} if ($args{uuid} =~ /$pattern/i);
    diag("String did not match UUID pattern:\nString: '$args{uuid}'\nPattern: '$pattern'");
    return 0;
}


=head2 az_storage_blob_upload

    az_storage_blob_upload(
        container_name=>'somecontainer',
        storage_account_name=>'storageaccount',
        file=>'somefilename' [, timeout=>42]);

Uploads file to a storage container.

=over 4

=item B<container_name> Existing storage container name.

=item B<storage_account_name> Storage account name.

=item B<file> File to upload.

=item B<timeout> Timeout for az command. Default: 90s

=back
=cut

sub az_storage_blob_upload {
    my (%args) = @_;
    foreach ('container_name', 'storage_account_name', 'file') {
        croak "Missing mandatory argument: '$_'" unless $args{$_};
    }
    $args{timeout} //= '90';

    my $az_cmd = join(' ',
        'az storage blob upload',
        '--only-show-errors',
        "--container-name $args{container_name}",
        "--account-name $args{storage_account_name}",
        "--file $args{file}"
    );
    assert_script_run(join(' ', $az_cmd), timeout => $args{timeout});
}

=head2 az_storage_blob_lease_acquire

    az_storage_blob_lease_acquire(
        container_name=>'somecontainer',
        storage_account_name=>'storageaccount',
        blob_name => 'somefilename' [, lease_duration=>'42']
    );

Acquire a lease for a storage blob. Function returns UUID which is then required to modify the file and gives the
UUID owner exclusive rights.
Optionally B<lease_duration> can be defined to limit this file lock up to 60s instead of infinity.
In case of function returns nothing, the reasons may vary and it is up to caller to decide how to deal with the result.
In that case
Possible reasons are that there is already a lease present (az cli returns a message which is not a valid UUID)

=over 4

=item B<container_name> Existing storage container name.

=item B<storage_account_name> Storage account name.

=item B<blob_name> Blob name to acquire lease for.

=item B<lease_duration> Lease duration between 15-60s. Default: infinite

=back
=cut

sub az_storage_blob_lease_acquire {
    my (%args) = @_;
    foreach ('container_name', 'storage_account_name', 'blob_name') {
        croak "Missing mandatory argument: '$_'" unless $args{$_};
    }
    $args{lease_duration} //= '-1';    # -1 = infinite lease

    my $az_cmd = join(' ',
        'az storage blob lease acquire',
        '--only-show-errors',
        "--container-name $args{container_name}",
        "--account-name $args{storage_account_name}",
        "--blob-name $args{blob_name}",
        "--lease-duration $args{lease_duration}",
        '--output tsv'    # Json output won't work here.
                          # If it is not possible to acquire lease command will return a message which is not in json format.
                          # decode_json() would cause function to fail instead of just returning
    );

    my $lease_id = script_output($az_cmd, proceed_on_failure => 1);
    record_info('AZ CLI out', "AZ CLI returned output:\n $lease_id");
    return ($lease_id) if az_validate_uuid_pattern(uuid => $lease_id);    # Return only valid output.
}

=head2 az_storage_blob_list

    az_storage_blob_list(
        container_name=>'somecontainer',
        storage_account_name=>'storageaccount' [, query=>'[].name']
    );

List information about storage blob(s) specified by B<storage_account_name>, B<container_name> and B<query>.

=over 3

=item B<container_name> Existing storage container name.

=item B<storage_account_name> Storage account name.

=item B<query> Query in jmespath format

=back
=cut

sub az_storage_blob_list {
    my (%args) = @_;
    foreach ('container_name', 'storage_account_name') {
        croak "Missing mandatory argument: '$_'" unless $args{$_};
    }
    $args{query} //= '[].name';

    my $az_cmd = join(' ',
        'az storage blob list',
        '--only-show-errors',
        "--container-name $args{container_name}",
        "--account-name $args{storage_account_name}",
        "--query \"$args{query}\"",
        '--output json'
    );

    return decode_json(script_output($az_cmd));
}

=head2 az_storage_blob_update

    az_storage_blob_update(container_name=>'container', account_name=>'stuff', name='blobby' [, lease_id=42]);

Update properties of storage blob. Returns az cli command exit code.

=over 4

=item B<container_name> Existing resource group name.

=item B<account_name> Name of the resource to delete

=item B<name> Blob name

=item B<lease_id> Lease id in case there is a lease put on a file

=back
=cut

sub az_storage_blob_update {
    my (%args) = @_;
    foreach ('container_name', 'account_name', 'name') {
        croak "Missing mandatory argument: '$_'" unless $args{$_};
    }

    my @az_cmd = ('az storage blob update',
        '--only-show-errors',
        '--container-name', $args{container_name},
        '--account-name', $args{account_name},
        '--name', $args{name},
        '--output json'
    );
    push(@az_cmd, "--lease-id $args{lease_id}") if $args{lease_id};

    return script_run(join(' ', @az_cmd));
}

=head2 az_keyvault_list

    az_keyvault_list(resource_group=>'resource group' [, query=>'[].id']);

Lists all keyvault resource names located in specified resource group.
Output can be modified using B<query> argument.

=over

=item B<resource_group> Existing resource group name.

=item B<query> Modify output filter using jmespath query

=back
=cut

sub az_keyvault_list {
    my (%args) = @_;
    croak "Missing mandatory argument: 'resource_group'" unless $args{resource_group};
    $args{query} //= '[].name';

    my @az_cmd = ('az keyvault list',
        '--only-show-errors',
        '--resource-group', $args{resource_group},
        '--query', "$args{query}",
        '--output json'
    );

    return decode_json(script_output(join(' ', @az_cmd)));
}

=head2 az_keyvault_secret_list

    az_keyvault_secret_list(vault_name=>'Gringotts' [, query=>'[].id']);

Lists all keyvault secret names located in specified keyvault.
Output can be modified using B<query> argument.

=over

=item B<vault_name> Existing keyvault name.

=item B<query> Modify output filter using jmespath query

=back
=cut

sub az_keyvault_secret_list {
    my (%args) = @_;
    croak "Missing mandatory argument: 'vault_name'" unless $args{vault_name};
    $args{query} //= '[].name';

    my @az_cmd = ('az keyvault secret list',
        '--only-show-errors',
        '--vault-name', $args{vault_name},
        '--query', "$args{query}",
        '--output json'
    );

    return decode_json(script_output(join(' ', @az_cmd)));
}

=head2 az_keyvault_secret_show

    az_keyvault_secret_show(id=>'someid'
        [, name=>'Vault 713', vault_name=>'Gringotts', query=>'[].id', output=>'json', save_to_file=>'/alohomora']);

Lists all keyvault secret names located in specified keyvault.
Output can be modified using B<query> argument.

=over

=item B<id> Existing secret resource ID. B<name> and B<vault_name> not needed if this is specified.

=item B<name> Existing secret name. Required if B<id> not used.

=item B<vault_name> Existing keyvault name. Required if B<id> not used.

=item B<query> Modify output filter using jmespath query. Default: value

=item B<output> Output format.  Allowed values: json, tsv. Default: tsv.

=item B<save_to_file> Save output to a file specified.
    This can be used to prevent the secret being shown in OpenQA outputs. Default: undefined/false

=back
=cut

sub az_keyvault_secret_show {
    my (%args) = @_;
    croak 'Argument "id" cannot be used together with "name" and "vault_name".'
      if $args{id} and grep(/name|vault_name/, keys %args);
    croak 'Missing mandatory argument: id' if !$args{id} and !grep(/name|vault_name/, keys %args);
    foreach ('name', 'vault_name') {
        croak 'Missing mandatory argument: ' . $_ if !$args{id} and !$args{$_};
    }

    $args{query} //= 'value';
    # 'tsv' is default because json mangles newlines. It's easier to use output directly.
    $args{output} //= 'tsv';

    my @az_cmd = ('az keyvault secret show',
        '--only-show-errors',
        '--query', "$args{query}",
        '--output', "$args{output}"
    );
    push(@az_cmd, "--vault-name $args{vault_name}") if $args{vault_name};
    push(@az_cmd, "--name $args{name}") if $args{name};
    push(@az_cmd, "--id $args{id}") if $args{id};
    push(@az_cmd, "> $args{save_to_file}") if $args{save_to_file};

    return decode_json(script_output(join(' ', @az_cmd))) if $args{output} eq 'json';
    return script_output(join(' ', @az_cmd));
}
