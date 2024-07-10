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
  ipaddr2_create_cluster
  ipaddr2_deployment_sanity
  ipaddr2_deployment_logs
  ipaddr2_os_sanity
  ipaddr2_bastion_pubip
  ipaddr2_internal_key_accept
  ipaddr2_internal_key_gen
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

=over 3

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

    foreach my $i (1 .. 2) {
        az_vm_wait_running(
            resource_group => $rg,
            name => ipaddr2_get_internal_vm_name(id => $i));
    }
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
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

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
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

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

=head2 ipaddr2_internal_key_accept

    ipaddr2_internal_key_accept()

For the worker to accept the ssh key of the internal VMs

=over 1

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back
=cut

sub ipaddr2_internal_key_accept {
    my (%args) = @_;
    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    my $bastion_ssh_addr = ipaddr2_bastion_ssh_addr(bastion_ip => $args{bastion_ip});

    my ($vm_name, $vm_addr);
    foreach my $i (1 .. 2) {
        $vm_name = ipaddr2_get_internal_vm_private_ip(id => $i);
        $vm_addr = "$user\@$vm_name";

        # The worker reach the remote internal VM through
        # the bastion using ssh proxy mode.
        # This workers - internal_VM connection is only used
        # for test purpose, to observe from the external
        # what is going on inside the SUT.
        my $ret;

        # Sometimes it fails, do not know why.
        # Try two different variants of the same command.
        $ret = script_run(join(' ',
                'ssh',
                '-vvv',
                '-oStrictHostKeyChecking=accept-new',
                '-oConnectionAttempts=120',
                '-J', $bastion_ssh_addr,
                $vm_addr,
                'whoami'));

        if ($ret) {
            record_info("1 StrictHostKeyChecking", "ret:$ret");

            $ret = script_run(join(' ',
                    'ssh',
                    '-vvv',
                    $vm_addr,
                    "-oProxyCommand=\"ssh $bastion_ssh_addr -oConnectionAttempts=120 -W %h:%p\"",
                    '-oStrictHostKeyChecking=accept-new',
                    #'-oConnectionAttempts=60',
                    'whoami'));
            die "2 StrictHostKeyChecking --> ret:$ret" if $ret;
        }
        # one more without StrictHostKeyChecking=accept-new just to verify it is ok
        ipaddr2_ssh_internal(id => $i,
            cmd => 'whoami',
            bastion_ip => $args{bastion_ip});
    }
}

=head2 ipaddr2_internal_key_gen

    ipaddr2_internal_key_gen()

Create, on the /tmp folder of the Worker, two ssh key set.
One ssk yey pair for each internal VM
Then upload in each internal VM the ssh key pair using
scp in Proxy mode

=over 1

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back
=cut

sub ipaddr2_internal_key_gen {
    my (%args) = @_;
    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    my $bastion_ssh_addr = ipaddr2_bastion_ssh_addr(bastion_ip => $args{bastion_ip});
    my $user_ssh = "/home/$user/.ssh";
    my ($vm_name, $vm_addr, $this_tmp);
    my @pubkey;
    foreach my $i (1 .. 2) {
        $vm_name = ipaddr2_get_internal_vm_private_ip(id => $i);
        $vm_addr = "$user\@$vm_name";

        # Check if the folder /home/${MY_USERNAME}/.ssh exist in the $vm"
        ipaddr2_ssh_internal(id => $i,
            cmd => "sudo [ -d $user_ssh ]",
            bastion_ip => $args{bastion_ip});

        # Generate public/private keys pair for cloudadmin user on the internal VMs.
        # Generate them on the openQA worker, in a folder within /tmp.
        # The keys will be distributed using ssh and scp in Proxy mode.
        $this_tmp = ipaddr2_get_worker_tmp_for_internal_vm(id => $i);
        #assert_script_run("rm -rf $this_tmp");
        assert_script_run("mkdir -p $this_tmp");
        assert_script_run(join(' ',
                'ssh-keygen',
                '-N ""',
                '-t rsa',
                "-C \"Temp internal cluster key for $user on $vm_name\"",
                '-f', "$this_tmp/$key_id"));

        # Save the pubkey for later
        push @pubkey, script_output("cat $this_tmp/$key_id.pub");
        my $remote_key_tmp_path;
        my $remote_key_home_path;
        foreach my $this_key ($key_id, "$key_id.pub") {
            $remote_key_tmp_path = "/tmp/$this_key";
            $remote_key_home_path = "$user_ssh/$this_key";
            assert_script_run(join(' ',
                    'scp',
                    '-J', $bastion_ssh_addr,
                    join('/', $this_tmp, $this_key),
                    "$vm_addr:$remote_key_tmp_path"));
            ipaddr2_ssh_internal(id => $i,
                cmd => "sudo mv $remote_key_tmp_path $remote_key_home_path",
                bastion_ip => $args{bastion_ip});
            ipaddr2_ssh_internal(id => $i,
                cmd => "sudo chown $user:users $remote_key_home_path",
                bastion_ip => $args{bastion_ip});
            ipaddr2_ssh_internal(id => $i,
                cmd => "sudo chmod 0600 $remote_key_home_path",
                bastion_ip => $args{bastion_ip});
            ipaddr2_ssh_internal(id => $i,
                cmd => "sudo ls -lai $remote_key_home_path",
                bastion_ip => $args{bastion_ip});
        }
    }

    # Put vm-01 pub key as authorized key in vm-02
    ipaddr2_ssh_internal(id => 2,
        cmd => "echo \"$pubkey[0]\" >> /home/$user/.ssh/authorized_keys",
        bastion_ip => $args{bastion_ip});
    # Put vm-02 pub key as authorized key in vm-01
    ipaddr2_ssh_internal(id => 1,
        cmd => "echo \"$pubkey[1]\" >> /home/$user/.ssh/authorized_keys",
        bastion_ip => $args{bastion_ip});

    # vm-01 first connection to vm-02
    ipaddr2_ssh_internal(id => 1,
        cmd => join(' ',
            'ssh',
            $user . '@' . ipaddr2_get_internal_vm_private_ip(id => 2),
            '-oStrictHostKeyChecking=accept-new',
            'whoami'),
        bastion_ip => $args{bastion_ip});
    # vm-02 first connection to vm-01
    ipaddr2_ssh_internal(id => 2,
        cmd => join(' ',
            'ssh',
            $user . '@' . ipaddr2_get_internal_vm_private_ip(id => 1),
            '-oStrictHostKeyChecking=accept-new',
            'whoami'),
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

=head2 ipaddr2_os_sanity

    ipaddr2_os_sanity()

Run some OS level checks on the various VMs composing the deployment.
die in case of failure

=over 1

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back
=cut

sub ipaddr2_os_sanity {
    my (%args) = @_;
    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    ipaddr2_os_connectivity_sanity(bastion_ip => $args{bastion_ip});
    ipaddr2_os_network_sanity(bastion_ip => $args{bastion_ip});
    ipaddr2_os_ssh_sanity(bastion_ip => $args{bastion_ip});

    foreach my $i (1 .. 2) {
        # Check if ssh without password works between
        # the bastion and each of the internal VMs
        ipaddr2_ssh_internal(id => $i,
            cmd => "whoami | grep $user",
            bastion_ip => $args{bastion_ip});

        # check root
        ipaddr2_ssh_internal(id => $i,
            cmd => 'sudo whoami | grep root',
            bastion_ip => $args{bastion_ip});
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
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

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
        foreach my $addr (
            ipaddr2_get_internal_vm_name(id => $i),
            ipaddr2_get_internal_vm_private_ip(id => $i)) {
            foreach my $cmd ('ping -c 3 ', 'tracepath ', 'dig ') {
                ipaddr2_ssh_assert_script_run_bastion(
                    cmd => "$cmd $addr",
                    bastion_ip => $args{bastion_ip});
            }
        }
    }
}

=head2 ipaddr2_os_network_sanity

    ipaddr2_os_network_sanity()

Check that private IP are in the network configuration on the internal VMs

=over 1

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back
=cut

sub ipaddr2_os_network_sanity {
    my (%args) = @_;
    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    foreach my $i (1 .. 2) {
        ipaddr2_ssh_internal(id => $i,
            cmd => 'ip a show eth0 | grep -E "inet .*192\.168"',
            bastion_ip => $args{bastion_ip});
    }
}

=head2 ipaddr2_os_ssh_sanity

    ipaddr2_os_ssh_sanity()

Run some OS level checks on the various VMs ssh keys and configs.
die in case of failure

=over 1

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back
=cut

sub ipaddr2_os_ssh_sanity {
    my (%args) = @_;
    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    my $user_ssh = "/home/$user/.ssh";
    foreach my $i (1 .. 2) {
        # Check if the folder /home/$user/.ssh
        # exist in the $this internal VM
        ipaddr2_ssh_internal(id => $i,
            cmd => "sudo [ -d $user_ssh ]",
            bastion_ip => $args{bastion_ip});

        # Check if the key /home/$user/.ssh/$key_id
        # exists in this internal VM.
        ipaddr2_ssh_internal(id => $i,
            cmd => "sudo [ -f $user_ssh/$key_id ]",
            bastion_ip => $args{bastion_ip});

        # Check authorized_keys content
        ipaddr2_ssh_internal(id => $i,
            cmd => "cat $user_ssh/authorized_keys",
            bastion_ip => $args{bastion_ip});

        my $res = ipaddr2_ssh_internal_output(id => $i,
            cmd => "cat $user_ssh/authorized_keys | wc -l",
            bastion_ip => $args{bastion_ip});
        die "User $user on internal VM $i should have 3 keys instead of $res" unless $res eq '3';

        # Each internal VM has some pub keys from the pair
        # generated by the test code during the configure step
        ipaddr2_ssh_internal(id => $i,
            cmd => "cat $user_ssh/authorized_keys | grep \"Temp internal cluster key for\"",
            bastion_ip => $args{bastion_ip});
    }
}

=head2 ipaddr2_ssh_assert_script_run_bastion

    ipaddr2_ssh_assert_script_run_bastion(
        bastion_ip => '1.2.3.4',
        cmd => 'whoami');

run a command on the bastion using assert_script_run

=over 2

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=item B<cmd> - command to run there

=back
=cut

sub ipaddr2_ssh_assert_script_run_bastion {
    my (%args) = @_;
    croak("Argument < cmd > missing") unless $args{cmd};
    $args{bastion_ip} //= ipaddr2_bastion_pubip();
    my $bastion_ssh_addr = ipaddr2_bastion_ssh_addr(bastion_ip => $args{bastion_ip});

    assert_script_run(join(' ',
            'ssh',
            $bastion_ssh_addr,
            "'$args{cmd}'"));
}

=head2 ipaddr2_ssh_internal_cmd

    script_run(ipaddr2_ssh_internal_cmd(
        id => 2,
        bastion_ip => '1.2.3.4',
        cmd => 'whoami'));

Compose an ssh command. Command is composed to be executed on one of the two internal VM.
Command will use -J option to use the bastion as a proxy.
This function does not really execute any command, it only return a string.
Other functions can use result command string as input for various testapi functions,
like assert_script_run or script_output.

=over 3

=item B<id> - ID of the internal VM. Used to compose its name and as address for ssh.

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=item B<cmd> - Command to be run on the internal VM.

=back
=cut

sub ipaddr2_ssh_internal_cmd {
    my (%args) = @_;
    foreach (qw(id cmd)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{bastion_ip} //= ipaddr2_bastion_pubip();
    my $bastion_ssh_addr = ipaddr2_bastion_ssh_addr(bastion_ip => $args{bastion_ip});

    return join(' ',
        'ssh', '-J', $bastion_ssh_addr,
        "$user\@" . ipaddr2_get_internal_vm_private_ip(id => $args{id}),
        "'$args{cmd}'");
}

=head2 ipaddr2_ssh_internal

    ipaddr2_ssh_internal(
        id => 2,
        bastion_ip => '1.2.3.4',
        cmd => 'whoami');

run a command on one of the two internal VM through the bastion
using the assert_script_run API

=over 3

=item B<id> - ID of the internal VM. Used to compose its name and as address for ssh.

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=item B<cmd> - Command to be run on the internal VM.

=back
=cut

sub ipaddr2_ssh_internal {
    my (%args) = @_;
    foreach (qw(id cmd)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    assert_script_run(ipaddr2_ssh_internal_cmd(
            id => $args{id},
            bastion_ip => $args{bastion_ip},
            cmd => $args{cmd}));
}

=head2 ipaddr2_ssh_internal_output

    ipaddr2_ssh_internal_output(
        id => 2,
        bastion_ip => '1.2.3.4',
        cmd => 'whoami');

Runs $cmd  through the bastion on one of the two internal VMs using script_output.
Return the command output.

=over 3

=item B<id> - ID of the internal VM. Used to compose its name and as address for ssh.

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=item B<cmd> - Command to be run on the internal VM.

=back
=cut

sub ipaddr2_ssh_internal_output {
    my (%args) = @_;
    foreach (qw(id cmd)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    return script_output(ipaddr2_ssh_internal_cmd(
            id => $args{id},
            bastion_ip => $args{bastion_ip},
            cmd => $args{cmd}));
}

=head2 ipaddr2_create_cluster

    ipaddr2_create_cluster();

Initialize and configure the Pacemaker cluster on the two internal nodes

=over 1

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back
=cut

sub ipaddr2_create_cluster {
    my (%args) = @_;
    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    ipaddr2_ssh_internal(id => 1,
        cmd => 'sudo crm cluster init -y --name DONALDUCK',
        bastion_ip => $args{bastion_ip});

    ipaddr2_ssh_internal(id => 2,
        cmd => "sudo crm cluster join -y -c $user\@" . ipaddr2_get_internal_vm_private_ip(id => 1),
        bastion_ip => $args{bastion_ip});

    ipaddr2_ssh_internal(id => 1,
        cmd => 'sudo crm configure property maintenance-mode=true',
        bastion_ip => $args{bastion_ip});

    ipaddr2_ssh_internal(id => 1,
        cmd => join(' ',
            'sudo crm configure primitive',
            'rsc_ip_00',
            'ocf:heartbeat:IPaddr2',
            'meta target-role="Started"',
            'operations \$id="rsc_ip_RES-operations"',
            'op monitor interval="10s" timeout="20s"',
            "params ip=\"$frontend_ip\""),
        bastion_ip => $args{bastion_ip});

    ipaddr2_ssh_internal(id => 1,
        cmd => join(' ',
            'sudo crm configure primitive',
            'rsc_alb_00',
            'azure-lb',
            'port=62500',
            'op monitor  interval="10s" timeout="20s"'),
        bastion_ip => $args{bastion_ip});

    ipaddr2_ssh_internal(id => 1,
        cmd => join(' ',
            'sudo crm configure group',
            'rsc_grp_00', 'rsc_alb_00', 'rsc_ip_00'),
        bastion_ip => $args{bastion_ip});

    ipaddr2_ssh_internal(id => 1,
        cmd => 'sudo crm configure property maintenance-mode=false',
        bastion_ip => $args{bastion_ip});
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

=over 1

=item B<id> - VM id number

=back
=cut

sub ipaddr2_get_internal_vm_name {
    my (%args) = @_;
    croak("Argument < id > missing") unless $args{id};
    return DEPLOY_PREFIX . "-vm-0$args{id}";
}

=head2 ipaddr2_get_internal_vm_private_ip

    my $private_ip = ipaddr2_get_internal_vm_private_ip(42);

compose and return a string representing the VM private IP

=over 1

=item B<id> - VM id number

=back
=cut

sub ipaddr2_get_internal_vm_private_ip {
    my (%args) = @_;
    croak("Argument < id > missing") unless $args{id};
    return $priv_ip_range . '0.4' . $args{id};
}

=head2 ipaddr2_get_worker_tmp_for_internal_vm

    my $vm_tmp = ipaddr2_get_worker_tmp_for_internal_vm(42);

Return a path in /tmp of the worker used to store files associated
two one of the internal VM
=cut

sub ipaddr2_get_worker_tmp_for_internal_vm {
    my (%args) = @_;
    croak("Argument < id > missing") unless $args{id};
    return "/tmp/" . ipaddr2_get_internal_vm_name(id => $args{id});
}

1;
