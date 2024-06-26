# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Library sub and shared data for the ipaddr2 cloud test.

package sles4sap::ipaddr2;
use strict;
use warnings FATAL => 'all';
use testapi;
use Carp qw(croak);
use Exporter qw(import);
use mmapi 'get_current_job_id';
use sles4sap::azure_cli;
use publiccloud::utils;


=head1 SYNOPSIS

Library to manage ipaddr2 tests
=cut

our @EXPORT = qw(
  ipaddr2_azure_deployment
  ipaddr2_bastion_key_accept
  ipaddr2_destroy
  ipaddr2_get_internal_vm_name
  ipaddr2_deployment_sanity
  ipaddr2_deployment_logs
  ipaddr2_os_connectivity_sanity
  ipaddr2_bastion_pubip
);

use constant DEPLOY_PREFIX => 'ip2t';

our $user = 'cloudadmin';
our $bastion_vm_name = DEPLOY_PREFIX . "-vm-bastion";
our $bastion_pub_ip = DEPLOY_PREFIX . '-pub_ip';
# Storage account name must be between 3 and 24 characters in length and use numbers and lower-case letters only.
our $storage_account = DEPLOY_PREFIX . 'storageaccount';
our $priv_ip_range = '192.168.';
our $frontend_ip = $priv_ip_range . '0.50';
our $key_id = 'id_rsa';

=head2 ipaddr2_azure_resource_group

    my $rg = ipaddr2_azure_resource_group();

Get the Azure resource group name for this test
=cut

sub ipaddr2_azure_resource_group {
    return DEPLOY_PREFIX . get_current_job_id();
}

=head2 ipaddr2_azure_storage_account

    my $storage account = ipaddr2_azure_storage_account();

Get a unique storage account name. Not including the jobId
result in error like:
The storage account named ip2tstorageaccount already exists under the subscription
=cut

sub ipaddr2_azure_storage_account {
    return $storage_account . get_current_job_id();
}

=head2 ipaddr2_azure_deployment

    my $rg = ipaddr2_azure_deployment();

Create a deployment in Azure designed for this specific test.

1. Create a resource group to contain all
2. Create a vnet and subnet in it
3. Create one Public IP
4. Create 2 VM to run the cluster, both running a webserver and that are behind the LB
5. Create 1 additional VM that get
6. Create a Load Balancer with 2 VM in backend and with an IP as frontend

=over 2

=item B<region> - existing resource group

=item B<os> - existing Load balancer NAME

=item B<diagnostic> - enable diagnostic features if 1

=back
=cut

sub ipaddr2_azure_deployment {
    my (%args) = @_;
    foreach (qw(region os)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{diagnostic} //= 0;

    az_version();

    my $rg = ipaddr2_azure_resource_group();

    az_group_create(
        name => $rg,
        region => $args{region});

    # Create a VNET only needed later when creating the VM
    my $vnet = DEPLOY_PREFIX . '-vnet';
    my $subnet = DEPLOY_PREFIX . '-snet';
    az_network_vnet_create(
        resource_group => $rg,
        region => $args{region},
        vnet => $vnet,
        address_prefixes => $priv_ip_range . '0.0/16',
        snet => $subnet,
        subnet_prefixes => $priv_ip_range . '0.0/24');

    # Create a Network Security Group
    # only needed later when creating the VM
    my $nsg = DEPLOY_PREFIX . '-nsg';
    az_network_nsg_create(
        resource_group => $rg,
        name => $nsg);

    # Create the only one public IP in this deployment,
    # it will be assigned to the 3rd VM (bastion role)
    az_network_publicip_create(
        resource_group => $rg,
        name => $bastion_pub_ip,
        sku => 'Basic',
        allocation_method => 'Static');

    # Create the load balancer entity.
    # Mostly this one is just a "group" definition
    # to link back-end (2 VMs) and front-end (the Pub IP) resources
    # SKU Standard (and not Basic) is needed to get some Metrics
    my $lb = DEPLOY_PREFIX . '-lb';
    my $lb_be = DEPLOY_PREFIX . '-backend_pool';
    my $lb_fe = DEPLOY_PREFIX . '-frontent_ip';
    az_network_lb_create(
        resource_group => $rg,
        name => $lb,
        vnet => $vnet,
        snet => $subnet,
        backend => $lb_be,
        frontend_ip_name => $lb_fe,
        fip => $frontend_ip,
        sku => 'Standard');

    # All the 2 VM will be later assigned to it.
    # The load balancer does not explicitly knows about it
    my $as = DEPLOY_PREFIX . '-as';
    az_vm_as_create(
        resource_group => $rg,
        name => $as,
        region => $args{region},
        fault_count => 2);

    if ($args{diagnostic}) {
        az_storage_account_create(
            resource_group => $rg,
            region => $args{region},
            name => ipaddr2_azure_storage_account());
    }

    # Create 2:
    #   - VMs
    #   - for each of them open port 80
    #   - link their NIC/ipconfigs to the load balancer to be managed
    my $vm;
    my $cloud_init_file = '/tmp/cloud-init-web.txt';
    assert_script_run(join(' ',
            'curl -v -fL',
            data_url('sles4sap/cloud-init-web.txt'),
            '-o', $cloud_init_file));
    foreach my $i (1 .. 2) {
        $vm = ipaddr2_get_internal_vm_name(id => $i);
        # the VM creation command refers to an external cloud-init
        # configuration file that is in charge to install and setup
        # the nginx server.
        az_vm_create(
            resource_group => $rg,
            name => $vm,
            region => $args{region},
            image => $args{os},
            username => $user,
            vnet => $vnet,
            snet => $subnet,
            availability_set => $as,
            nsg => $nsg,
            custom_data => $cloud_init_file,
            ssh_pubkey => get_ssh_private_key_path() . '.pub',
            public_ip => "");

        if ($args{diagnostic}) {
            az_vm_diagnostic_log_enable(resource_group => $rg,
                storage_account => ipaddr2_azure_storage_account(),
                vm_name => $vm);
        }

        az_vm_wait_cloudinit(
            resource_group => $rg,
            name => $vm,
            username => $user);

        az_vm_openport(
            resource_group => $rg,
            name => $vm, port => 80);
    }

    az_vm_create(
        resource_group => $rg,
        name => $bastion_vm_name,
        region => $args{region},
        image => $args{os},
        username => $user,
        vnet => $vnet,
        snet => $subnet,
        ssh_pubkey => get_ssh_private_key_path() . '.pub',
        public_ip => $bastion_pub_ip);

    # Keep this loop separated from the other to hopefully
    # give cloud-init more time to run and avoid interfering
    # with it by changing the networking on the running VM
    foreach my $i (1 .. 2) {
        my $vm = ipaddr2_get_internal_vm_name(id => $i);
        my $nic_id = az_nic_id_get(
            resource_group => $rg,
            name => $vm);
        my $ip_config = az_ipconfig_name_get(nic_id => $nic_id);
        my $nic_name = az_nic_name_get(nic_id => $nic_id);

        # Change the IpConfig to use a static IP:
        # https://documentation.suse.com/sle-ha/15-SP5/html/SLE-HA-all/article-installation.html#vl-ha-inst-quick-req-other
        az_ipconfig_update(
            resource_group => $rg,
            ipconfig_name => $ip_config,
            nic_name => $nic_name,
            ip => ipaddr2_get_internal_vm_private_ip(id => $i));

        # Add the IpConfig to the LB pool
        az_ipconfig_pool_add(
            resource_group => $rg,
            lb_name => $lb,
            address_pool => $lb_be,
            ipconfig_name => $ip_config,
            nic_name => $nic_name);
    }

    # Health probe is using the port exposed by the cluster RA azure-lb
    # to understand if each of the VM in the cluster is OK
    # Is probably eventually the cluster itself that
    # cares to monitor the below service (port 80)
    my $lbhp = $lb . "_health";
    my $lbhp_port = '62500';
    az_network_lb_probe_create(
        resource_group => $rg,
        lb_name => $lb,
        name => $lbhp,
        port => $lbhp_port);

    # Configure the load balancer behavior
    az_network_lb_rule_create(
        resource_group => $rg,
        lb_name => $lb,
        hp_name => $lbhp,
        backend => $lb_be,
        frontend_ip => $lb_fe,
        name => $lb . "_rule",
        port => '80');
}

=head2 ipaddr2_bastion_pubip

    my $bastion_ip = ipaddr2_bastion_pubip();

Get the only public IP in the deployment associated to the VM used as bastion.

=cut

sub ipaddr2_bastion_pubip {
    my $rg = ipaddr2_azure_resource_group();
    return az_network_publicip_get(
        resource_group => $rg,
        name => $bastion_pub_ip);
}

=head2 ipaddr2_bastion_ssh_addr

    script_run(join(' ', 'ssh', ipaddr2_bastion_ssh_addr(), 'whoami');

Help to create ssh command that target the only VM
in the deployment that has public IP.

=over 1

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.

=back
=cut

sub ipaddr2_bastion_ssh_addr {
    my (%args) = @_;
    $args{bastion_ip} //= ipaddr2_bastion_pubip();
    return $user . '@' . $args{bastion_ip};
}

=head2 ipaddr2_bastion_key_accept

    ipaddr2_bastion_key_accept()

For the worker to accept the ssh key of the bastion

=over 1

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.

=back
=cut

sub ipaddr2_bastion_key_accept {
    my (%args) = @_;
    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    my $bastion_ssh_addr = ipaddr2_bastion_ssh_addr(bastion_ip => $args{bastion_ip});
    # Clean up known_hosts on the machine running the test script
    #    ssh-keygen -R $bastion_ssh_addr
    # is not needed and has not to be executed
    # as /root/.ssh/known_hosts does not exist at all in the worker context.
    # Not strictly needed in this context as each test
    # in openQA start from a clean environment

    my $bastion_ssh_cmd = "ssh -vvv -oStrictHostKeyChecking=accept-new $bastion_ssh_addr";
    assert_script_run(join(' ', $bastion_ssh_cmd, 'whoami'));

    # one more without StrictHostKeyChecking=accept-new just to verify it is ok
    ipaddr2_ssh_assert_script_run_bastion(
        cmd => 'whoami',
        bastion_ip => $args{bastion_ip});
}


=head2 ipaddr2_deployment_sanity

    ipaddr2_deployment_sanity()

Run some checks on the existing deployment using the
az command line.
die in case of failure
=cut

sub ipaddr2_deployment_sanity {
    my $rg = ipaddr2_azure_resource_group();
    my $res = az_group_name_get();
    my $count = grep(/$rg/, @$res);
    die "There are not exactly one but $count resource groups with name $rg" unless $count eq 1;

    $res = az_vm_list(resource_group => $rg, query => '[].name');
    $count = grep(/$bastion_vm_name/, @$res);
    die "There are not exactly 3 VMs but " . ($#{$res} + 1) unless ($#{$res} + 1) eq 3;
    die "There are not exactly 1 but $count VMs with name $bastion_vm_name" unless $count eq 1;

    foreach my $i (1 .. 2) {
        my $vm = ipaddr2_get_internal_vm_name(id => $i);
        $res = az_vm_instance_view_get(
            resource_group => $rg,
            name => $vm);
        # Expected return is
        # [ "PowerState/running", "VM running" ]
        $count = grep(/running/, @$res);
        die "VM $vm is not fully running" unless $count eq 2;    # 2 is two occurrence of the word 'running' for one VM
    }
}

=head2 ipaddr2_os_connectivity_sanity

    ipaddr2_os_connectivity_sanity()

Run some OS level checks about internal connectivity.
die in case of failure

- bastion has to be able to ping the internal VM using the internal private IP
- bastion has to be able to ping the internal VM using the internal VM hostname

=over 1

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      managed as argument not to have to call ipaddr2_bastion_pubip many time,
                      so not to have to query az each time

=back
=cut

sub ipaddr2_os_connectivity_sanity {
    my (%args) = @_;
    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    # proceed_on_failure needed as ping or nc
    # coul dbe missing on the qcow2 running these commands
    # (for example pc_tools)
    script_run("ping -c 3 $args{bastion_ip}", proceed_on_failure => 1);
    script_run("nc -vz -w 1 $args{bastion_ip} 22", proceed_on_failure => 1);

    # Check if the bastion is able to ping
    # the VM by hostname and private IP
    foreach my $i (1 .. 2) {
        foreach my $addr (ipaddr2_get_internal_vm_private_ip(id => $i), ipaddr2_get_internal_vm_name(id => $i)) {
            foreach my $cmd ('ping -c 3 ', 'tracepath ', 'dig ') {
                ipaddr2_ssh_assert_script_run_bastion(
                    cmd => "$cmd $addr",
                    bastion_ip => $args{bastion_ip});
            }
        }
    }
}

=head2 ipaddr2_ssh_assert_script_run_bastion

    ipaddr2_ssh_assert_script_run_bastion(
        bastion_ip => '1.2.3.4',
        cmd => 'whoami');

run a command on the bastion using assert_script_run

=over 2

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      managed as argument not to have to call ipaddr2_bastion_pubip many time,
                      so not to have to query az each time

=item B<cmd> - command to run there

=back
=cut

sub ipaddr2_ssh_assert_script_run_bastion {
    my (%args) = @_;
    croak("Argument < cmd > missing") unless $args{cmd};
    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    assert_script_run(join(' ',
            'ssh',
            "$user\@" . $args{bastion_ip},
            "'$args{cmd}'"));
}

=head2 ipaddr2_deployment_logs

    ipaddr2_deployment_logs()

Collect logs from the cloud infrastructure
=cut

sub ipaddr2_deployment_logs {
    az_vm_diagnostic_log_get(resource_group => ipaddr2_azure_resource_group());
}

=head2 ipaddr2_destroy

    ipaddr2_destroy();

Destroy the deployment by deleting the resource group
=cut

sub ipaddr2_destroy {
    az_group_delete(name => ipaddr2_azure_resource_group(), timeout => 600);
}

=head2 ipaddr2_get_internal_vm_name

    my $vm_name = ipaddr2_get_internal_vm_name(42);

compose and return a string for the vm name
=cut

sub ipaddr2_get_internal_vm_name {
    my (%args) = @_;
    croak("Argument < id > missing") unless $args{id};
    return DEPLOY_PREFIX . "-vm-0$args{id}";
}

=head2 ipaddr2_get_internal_vm_private_ip

    my $private_ip = ipaddr2_get_internal_vm_private_ip(42);

compose and return a string representing the VM private IP
=cut

sub ipaddr2_get_internal_vm_private_ip {
    my (%args) = @_;
    croak("Argument < id > missing") unless $args{id};
    return $priv_ip_range . '0.4' . $args{id};
}

1;
