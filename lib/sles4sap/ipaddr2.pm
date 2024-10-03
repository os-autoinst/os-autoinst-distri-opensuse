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
use Carp qw( croak );
use Exporter qw(import);
use Mojo::JSON qw( decode_json );
use mmapi qw( get_current_job_id );
use sles4sap::azure_cli;
use publiccloud::utils qw( get_ssh_private_key_path );
use utils qw( write_sut_file );
use hacluster qw($crm_mon_cmd cluster_status_matches_regex);


=head1 SYNOPSIS

Library to manage ipaddr2 tests
=cut

our @EXPORT = qw(
  ipaddr2_azure_deployment
  ipaddr2_bastion_key_accept
  ipaddr2_destroy
  ipaddr2_create_cluster
  ipaddr2_configure_web_server
  ipaddr2_refresh_repo
  ipaddr2_deployment_sanity
  ipaddr2_deployment_logs
  ipaddr2_os_sanity
  ipaddr2_os_connectivity_sanity
  ipaddr2_cluster_sanity
  ipaddr2_bastion_pubip
  ipaddr2_internal_key_accept
  ipaddr2_internal_key_gen
  ipaddr2_registeration_check
  ipaddr2_registeration_set
  ipaddr2_crm_move
  ipaddr2_crm_clear
  ipaddr2_wait_for_takeover
  ipaddr2_test_master_vm
  ipaddr2_test_other_vm
  ipaddr2_os_cloud_init_logs
);

use constant DEPLOY_PREFIX => 'ip2t';
use constant WEB_RSC => 'rsc_web_00';

our $user = 'cloudadmin';
our $bastion_vm_name = DEPLOY_PREFIX . "-vm-bastion";
our $bastion_pub_ip = DEPLOY_PREFIX . '-pub_ip';
our $nat_pub_ip = DEPLOY_PREFIX . '-nat_pub_ip';
# Storage account name must be between 3 and 24 characters in length
# and use numbers and lower-case letters only.
our $storage_account = DEPLOY_PREFIX . 'storageaccount';
our $priv_ip_range = '192.168.';
our $frontend_ip = $priv_ip_range . '0.50';
our $ping_cmd = 'ping -c 3';
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
4. Create 2 VM to run the cluster, both running a web server and that are behind the LB
5. Create 1 additional VM that get
6. Create a Load Balancer with 2 VM in backend and with an IP as frontend

=over 5

=item B<region> - existing resource group

=item B<os> - existing Load balancer NAME

=item B<diagnostic> - enable diagnostic features if 1

=item B<cloudinit> - enable cloud-init features if 1. This feature is used to install
                      the web server using cloud-init, by providing an external
                      cloud-init config file. This feature cannot be used for BYOS images
                      as installing additional packages is not supported before
                      the image registration. This feature could be problematic
                      when testing maintenance update: problem is that the config file
                      also perform a `zypper patch`. It happens at the first boot
                      during the deployment so before any other part of the test can add
                      additional repo to test.

=item B<trusted_launch> - Enable or disable Trusted Launch. Default 1: Enabled.
                          If configured to 0 the result in az vm create is executed with '--security-type Standard'

=item B<scc_code> - if cloudinit is enabled, it is also possible to add
                    register command in it. This argument is just ignored if cloudinit is 0.
                    This argument become mandatory is cloudinit is 1 and image is BYOS.
                    This is because cloud-init also try to install nginx,
                    but installing packages is not possible for BYOS images,
                    before registering.

=back
=cut

sub ipaddr2_azure_deployment {
    my (%args) = @_;
    foreach (qw(region os)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{diagnostic} //= 0;
    $args{cloudinit} //= 1;
    $args{trusted_launch} //= 1;

    if ($args{cloudinit} && ($args{os} =~ /byos/i) && !$args{scc_code}) {
        croak("cloud-init deployment does not work with BYOS images without a registration code");
    }

    az_version();

    my $rg = ipaddr2_azure_resource_group();

    az_group_create(
        name => $rg,
        region => $args{region});

    # Create a VNET only needed later when creating the VM
    # Use $rg instead of DEPLOY_PREFIX to try to prevent
    # some deployment failures like:
    #    Subnet(ip2t-snet) does not exist, but failed to create a new subnet
    #    with address prefix 10.0.0.0/24.
    my $vnet = "$rg-vnet";
    my $subnet = "$rg-snet";
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

    # Create a public IP for external test access.
    # It will be assigned to the 3rd VM (bastion role)
    az_network_publicip_create(
        resource_group => $rg,
        name => $bastion_pub_ip,
        sku => 'Standard',
        allocation_method => 'Static');

    # Create a public IP for the NAT Gateway
    az_network_publicip_create(
        resource_group => $rg,
        name => $nat_pub_ip,
        sku => 'Standard',
        allocation_method => 'Static');

    # Create the NAT Gateway
    my $nat_name = DEPLOY_PREFIX . '-nat';
    az_network_nat_gateway_create(
        resource_group => $rg,
        region => $args{region},
        name => $nat_name,
        public_ip => $nat_pub_ip);

    # Associate one of the Public IP to the NAT Gateway
    az_network_vnet_subnet_update(
        resource_group => $rg,
        vnet => $vnet,
        snet => $subnet,
        nat_gateway => $nat_name);

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

    # If required, create on the fly the cloud-init script
    my $cloud_init_file;
    if ($args{cloudinit}) {
        my $cloud_init_content = <<END;
#cloud-config
package_upgrade: false
packages:
  - nginx
runcmd:
  - 'echo "I am \$(hostname)" > /srv/www/htdocs/index.html'
  - sudo systemctl enable --now nginx.service
END

        if ($args{scc_code}) {
            $cloud_init_content .= <<END;
bootcmd:
  - registercloudguest --clean
  - registercloudguest --force-new -r $args{scc_code}
END
        }
        $cloud_init_file = '/tmp/cloud-init-web.txt';
        write_sut_file($cloud_init_file, $cloud_init_content);
        # upload to allow debugging
        upload_logs($cloud_init_file);
    }

    # Create 2:
    #   - VMs
    #   - for each of them open port 80
    #   - link their NIC/ipconfigs to the load balancer to be managed
    my $vm;
    my %vm_create_generic_args = (
        resource_group => $rg,
        region => $args{region},
        image => $args{os},
        username => $user,
        vnet => $vnet,
        snet => $subnet,
        ssh_pubkey => get_ssh_private_key_path() . '.pub',
        public_ip => "");
    if (!$args{trusted_launch}) {
        $vm_create_generic_args{security_type} = 'Standard';
    }

    my %vm_create_internal_args = %vm_create_generic_args;
    $vm_create_internal_args{availability_set} = $as;
    $vm_create_internal_args{nsg} = $nsg;
    $vm_create_internal_args{public_ip} = "";
    if ($args{cloudinit}) {
        $vm_create_internal_args{custom_data} = $cloud_init_file;
    }

    foreach my $i (1 .. 2) {
        $vm = ipaddr2_get_internal_vm_name(id => $i);
        # the VM creation command refers to an external cloud-init
        # configuration file that is in charge to install and setup
        # the nginx server.
        $vm_create_internal_args{name} = $vm;
        az_vm_create(%vm_create_internal_args);

        if ($args{diagnostic}) {
            az_vm_diagnostic_log_enable(resource_group => $rg,
                storage_account => ipaddr2_azure_storage_account(),
                vm_name => $vm);
        }

        if ($args{cloudinit}) {
            az_vm_wait_cloudinit(
                resource_group => $rg,
                name => $vm,
                username => $user);
        }

        az_vm_openport(
            resource_group => $rg,
            name => $vm, port => 80);
    }

    my %vm_create_bastion_args = %vm_create_generic_args;
    $vm_create_bastion_args{name} = $bastion_vm_name;
    $vm_create_bastion_args{public_ip} = $bastion_pub_ip;
    az_vm_create(%vm_create_bastion_args);

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
            nic_name => $nic_name,
            timeput => 300);
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

    foreach (1 .. 2) {
        az_vm_wait_running(
            resource_group => $rg,
            name => ipaddr2_get_internal_vm_name(id => $_));
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
    ipaddr2_ssh_bastion_assert_script_run(
        cmd => 'whoami',
        bastion_ip => $args{bastion_ip});
}

=head2 ipaddr2_internal_key_accept

    ipaddr2_internal_key_accept()

For the worker to accept the ssh key of the internal VMs

=over 2

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=item B<key_checking> - optional parameter allow to tune value for StrictHostKeyChecking
                        ssh option. default to 'accept-new'

=back
=cut

sub ipaddr2_internal_key_accept {
    my (%args) = @_;
    $args{bastion_ip} //= ipaddr2_bastion_pubip();
    $args{key_checking} //= 'accept-new';
    my $key_policy = '-oStrictHostKeyChecking=' . $args{key_checking};

    my $bastion_ssh_addr = ipaddr2_bastion_ssh_addr(bastion_ip => $args{bastion_ip});

    my ($vm_name, $vm_addr, $ret, $start_time, $exit_code, $score);
    foreach my $i (1 .. 2) {
        $vm_name = ipaddr2_get_internal_vm_private_ip(id => $i);
        $vm_addr = "$user\@$vm_name";

        # The worker reaches the two remote internal VMs
        # through the bastion VM, using ssh proxy mode.
        # The connection between the worker and the internalVM
        # is used for test purpose, to observe from the external
        # what is going on inside the SUT.

        # Start by waiting that the ssh port is open
        $start_time = time();
        $exit_code = 1;
        $score = 0;
        while ((time() - $start_time) < 300) {
            $exit_code = ipaddr2_ssh_bastion_script_run(
                cmd => "nc -vz -w 1 $vm_name 22",
                bastion_ip => $args{bastion_ip});
            # sleep before to evaluate as, even if port is open,
            # it could take more time to be able to establish
            # the first ssh connection.
            sleep 10;

            # this score mechanism penalize more those systems
            # that are not ready when reaching this code.
            $score += (defined($exit_code) && $exit_code eq 0) ? +1 : -1;
            last if $score > 1;
        }
        die "ssh port 22 not available on VM $vm_name" if (!(defined($exit_code) && $exit_code eq 0));

        # Try two different variants of the same command.
        $ret = script_run(join(' ',
                'ssh',
                '-vvv',
                $key_policy,
                '-oConnectionAttempts=120',
                '-J', $bastion_ssh_addr,
                $vm_addr,
                'whoami'));

        if ($ret) {
            $ret = script_run(join(' ',
                    'ssh',
                    '-vvv',
                    $vm_addr,
                    "-oProxyCommand=\"ssh $bastion_ssh_addr -oConnectionAttempts=120 -W %h:%p\"",
                    $key_policy,
                    #'-oConnectionAttempts=60',
                    'whoami'));
            die "2 StrictHostKeyChecking --> ret:$ret" if $ret;
        }
        # one more without StrictHostKeyChecking just to verify it is ok
        ipaddr2_ssh_internal(id => $i,
            cmd => 'whoami',
            bastion_ip => $args{bastion_ip});
    }
}

=head2 ipaddr2_internal_key_gen

    ipaddr2_internal_key_gen()

Create, on the /tmp folder of the Worker, two ssh key set.
One ssk key pair for each internal VM
Then upload in each internal VM the ssh key pair using
scp in Proxy mode

=over 2

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=item B<key_checking> - optional parameter allow to tune value for StrictHostKeyChecking
                        ssh option. default to 'accept-new'

=back
=cut

sub ipaddr2_internal_key_gen {
    my (%args) = @_;
    $args{bastion_ip} //= ipaddr2_bastion_pubip();
    $args{key_checking} //= 'accept-new';
    my $key_policy = '-oStrictHostKeyChecking=' . $args{key_checking};

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

        # Save the ssh public key for later
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

    # Put vm-01 ssh public key as authorized key in vm-02
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
            $key_policy,
            'whoami'),
        bastion_ip => $args{bastion_ip});
    # vm-02 first connection to vm-01
    ipaddr2_ssh_internal(id => 2,
        cmd => join(' ',
            'ssh',
            $user . '@' . ipaddr2_get_internal_vm_private_ip(id => 1),
            $key_policy,
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

    foreach (1 .. 2) {
        my $vm = ipaddr2_get_internal_vm_name(id => $_);
        $res = az_vm_instance_view_get(
            resource_group => $rg,
            name => $vm);
        # Expected return is
        # [ "PowerState/running", "VM running" ]
        $count = grep(/running/, @$res);
        # 2 is two occurrence of the word 'running' for one VM
        die "VM $vm is not fully running" unless $count eq 2;
    }
}

=head2 ipaddr2_os_sanity

    ipaddr2_os_sanity()

Run some OS level checks on the various VMs composing the deployment.
die in case of failure. Tests are targeting all the VM.
Tests are independent by the cluster status.

=over 1

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back
=cut

sub ipaddr2_os_sanity {
    my (%args) = @_;
    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    ipaddr2_os_network_sanity(bastion_ip => $args{bastion_ip});
    ipaddr2_os_connectivity_sanity(bastion_ip => $args{bastion_ip});
    ipaddr2_os_ssh_sanity(bastion_ip => $args{bastion_ip});

    foreach (1 .. 2) {
        ipaddr2_ssh_internal(id => $_,
            cmd => 'sudo systemctl is-system-running',
            bastion_ip => $args{bastion_ip});
    }

    ipaddr2_os_cloud_init_sanity(bastion_ip => $args{bastion_ip});
}

=head2 ipaddr2_cluster_sanity

    ipaddr2_cluster_sanity()

Run some cluster level checks...

=over 2

=item B<id> - ID of the internal VM where to run the crm commands. Default is 1.

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back
=cut

sub ipaddr2_cluster_sanity {
    my (%args) = @_;
    $args{bastion_ip} //= ipaddr2_bastion_pubip();
    $args{id} //= 1;

    my $crm_status = ipaddr2_ssh_internal_output(id => $args{id},
        cmd => 'sudo crm status',
        bastion_ip => $args{bastion_ip});

    die "Issue in the cluster health" if cluster_status_matches_regex($crm_status);

    ipaddr2_ssh_internal(id => $args{id},
        cmd => "sudo $crm_mon_cmd",
        bastion_ip => $args{bastion_ip});

    my $crm_configure = ipaddr2_ssh_internal_output(id => $args{id},
        cmd => 'sudo crm configure show',
        bastion_ip => $args{bastion_ip});

    my @resources = $crm_configure =~ /primitive/g;
    die "Cluster on VM $args{id} has " . scalar @resources . " primitives instead of expected 3" unless (scalar @resources) eq 3;

    ipaddr2_ssh_internal(id => $args{id},
        cmd => '[ -f /usr/lib/ocf/resource.d/heartbeat/nginx ]',
        bastion_ip => $args{bastion_ip});
    ipaddr2_ssh_internal(id => $args{id},
        cmd => 'rpm -qf /usr/lib/ocf/resource.d/heartbeat/nginx',
        bastion_ip => $args{bastion_ip});
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

    # intentionally ignore the return as ping or nc
    # could be missing on the qcow2 running these commands
    # (for example pc_tools)
    script_run("$ping_cmd $args{bastion_ip}");
    script_run("nc -vz -w 1 $args{bastion_ip} 22");

    foreach my $i (1 .. 2) {
        # Check if the bastion is able to ping
        # the VM by hostname and private IP
        foreach my $addr (
            ipaddr2_get_internal_vm_private_ip(id => $i),
            ipaddr2_get_internal_vm_name(id => $i)) {
            foreach my $cmd ($ping_cmd, 'tracepath', 'dig') {
                ipaddr2_ssh_bastion_assert_script_run(
                    cmd => "$cmd $addr",
                    bastion_ip => $args{bastion_ip});
            }
        }
    }

    # Check if the two internal VM can ping one to each other
    ipaddr2_ssh_internal(
        id => 1,
        cmd => join(' ', $ping_cmd, ipaddr2_get_internal_vm_private_ip(id => 2)),
        bastion_ip => $args{bastion_ip});

    ipaddr2_ssh_internal(
        id => 2,
        cmd => join(' ', $ping_cmd, ipaddr2_get_internal_vm_private_ip(id => 1)),
        bastion_ip => $args{bastion_ip});
}

=head2 ipaddr2_os_cloud_init_sanity

    ipaddr2_os_cloud_init_sanity()

Run some checks about cloud-init

=over 1

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back
=cut

sub ipaddr2_os_cloud_init_sanity {
    my (%args) = @_;
    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    foreach my $id (1 .. 2) {
        foreach (
            'grep -E "root|cloudadmin|hacluster" /etc/passwd',
            'zypper se -s -i cloud-init',
            'cloud-init -v',
            'cloud-init status --wait --long',
            'sudo systemctl status \
              cloud-init-local.service \
              cloud-init.service \
              cloud-config.service \
              cloud-final.service') {
            ipaddr2_ssh_internal(id => $id,
                cmd => $_,
                bastion_ip => $args{bastion_ip});
        }
    }
}

=head2 ipaddr2_os_cloud_init_logs

    ipaddr2_os_cloud_init_logs()

Collect some cloud-init related logs

=over 1

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back
=cut

sub ipaddr2_os_cloud_init_logs {
    my (%args) = @_;
    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    foreach my $id (1 .. 2) {
        foreach (
            'sudo cat /var/log/cloud-init.log',
            'sudo cat /var/log/cloud-init-output.log',
            'sudo cloud-init collect-logs',
            'sudo cloud-init analyze show',
            'sudo cloud-init analyze dump',
            'sudo cloud-init analyze blame',
            'sudo cloud-init analyze boot || echo "rc:$?"',
            'sudo cloud-init schema --system',
            'sudo dmesg -T | grep -i -e warning -e error -e fatal -e exception',
            'tail -n 3 /run/cloud-init/ds-identify.log'
        ) {
            ipaddr2_ssh_internal(id => $id,
                cmd => $_,
                bastion_ip => $args{bastion_ip});
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

    foreach (1 .. 2) {
        ipaddr2_ssh_internal(id => $_,
            cmd => 'ip a show eth0 | grep -E "inet .*192\.168"',
            bastion_ip => $args{bastion_ip});
    }
}

=head2 ipaddr2_os_ssh_sanity

    ipaddr2_os_ssh_sanity()

Run some OS level checks on the various VMs ssh keys and configurations.
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

    # Check if ssh without password works between
    # the bastion and each of the internal VMs
    foreach my $i (1 .. 2) {
        ipaddr2_ssh_internal(id => $i,
            cmd => "whoami | grep $user",
            bastion_ip => $args{bastion_ip});

        # check root
        ipaddr2_ssh_internal(id => $i,
            cmd => 'sudo whoami | grep root',
            bastion_ip => $args{bastion_ip});
    }
}

=head2 ipaddr2_ssh_bastion_assert_script_run

    ipaddr2_ssh_bastion_assert_script_run(
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

sub ipaddr2_ssh_bastion_assert_script_run {
    my (%args) = @_;
    croak("Argument < cmd > missing") unless $args{cmd};
    $args{bastion_ip} //= ipaddr2_bastion_pubip();
    my $bastion_ssh_addr = ipaddr2_bastion_ssh_addr(bastion_ip => $args{bastion_ip});

    assert_script_run(join(' ',
            'ssh',
            $bastion_ssh_addr,
            "'$args{cmd}'"));
}

=head2 ipaddr2_ssh_bastion_script_run

    my $ret = ipaddr2_ssh_bastion_script_run(
        bastion_ip => '1.2.3.4',
        cmd => 'whoami');

run a command on the bastion using script_run

=over 2

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=item B<cmd> - command to run there

=back
=cut

sub ipaddr2_ssh_bastion_script_run {
    my (%args) = @_;
    croak("Argument < cmd > missing") unless $args{cmd};
    $args{bastion_ip} //= ipaddr2_bastion_pubip();
    my $bastion_ssh_addr = ipaddr2_bastion_ssh_addr(bastion_ip => $args{bastion_ip});

    return script_run(join(' ',
            'ssh',
            $bastion_ssh_addr,
            "'$args{cmd}'"));
}

=head2 ipaddr2_ssh_bastion_script_output

    my $ret = ipaddr2_ssh_bastion_script_output(
        bastion_ip => '1.2.3.4',
        cmd => 'whoami');

run a command on the bastion using script_output

=over 2

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=item B<cmd> - command to run there

=back
=cut

sub ipaddr2_ssh_bastion_script_output {
    my (%args) = @_;
    croak("Argument < cmd > missing") unless $args{cmd};
    $args{bastion_ip} //= ipaddr2_bastion_pubip();
    my $bastion_ssh_addr = ipaddr2_bastion_ssh_addr(bastion_ip => $args{bastion_ip});

    return script_output(join(' ',
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

=over 4

=item B<id> - ID of the internal VM. Used to compose its name and as address for ssh.

=item B<cmd> - Command to be run on the internal VM.

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=item B<timeout> - Execution timeout, default 90sec

=back
=cut

sub ipaddr2_ssh_internal {
    my (%args) = @_;
    foreach (qw(id cmd)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{bastion_ip} //= ipaddr2_bastion_pubip();
    $args{timeout} //= 90;

    assert_script_run(
        ipaddr2_ssh_internal_cmd(
            id => $args{id},
            bastion_ip => $args{bastion_ip},
            cmd => $args{cmd}),
        timeout => $args{timeout});
}

=head2 ipaddr2_ssh_internal_output

    ipaddr2_ssh_internal_output(
        id => 2,
        bastion_ip => '1.2.3.4',
        cmd => 'whoami');

Runs $cmd  through the bastion on one of the two internal VMs using script_output.
Return the command output.

=over 4

=item B<id> - ID of the internal VM. Used to compose its name and as address for ssh.

=item B<cmd> - Command to be run on the internal VM.

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=item B<timeout> - Execution timeout, default 90sec

=back
=cut

sub ipaddr2_ssh_internal_output {
    my (%args) = @_;
    foreach (qw(id cmd)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $args{bastion_ip} //= ipaddr2_bastion_pubip();
    $args{timeout} //= 90;

    return script_output(
        ipaddr2_ssh_internal_cmd(
            id => $args{id},
            bastion_ip => $args{bastion_ip},
            cmd => $args{cmd}),
        timeout => $args{timeout});
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
            WEB_RSC,
            'ocf:heartbeat:nginx',
            'configfile=/etc/nginx/nginx.conf',
            'op start timeout="40s" interval="0"',
            'op stop timeout="60s" interval="0"',
            'op monitor interval="10s" timeout="60s"',
            'meta migration-threshold="10"'),
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
            'rsc_grp_00', 'rsc_alb_00', 'rsc_ip_00', WEB_RSC),
        bastion_ip => $args{bastion_ip});

    ipaddr2_ssh_internal(id => 1,
        cmd => 'sudo crm configure property maintenance-mode=false',
        bastion_ip => $args{bastion_ip});
}

=head2 ipaddr2_registeration_check

    my $is_registered = ipaddr2_registeration_check(id => 1);

Check if image is registered. Return 1 is it is registered, 0 if at least one is not.

=over 2

=item B<id> - VM id where to install and configure the web server

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back

=cut

sub ipaddr2_registeration_check {
    my (%args) = @_;
    croak("Argument < id > missing") unless $args{id};

    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    # Initially suppose is registered
    my $registered = 1;
    my $json = decode_json(ipaddr2_ssh_internal_output(
            id => $args{id},
            cmd => 'sudo SUSEConnect -s',
            bastion_ip => $args{bastion_ip}));
    foreach (@$json) {
        if ($_->{status} =~ '^Not Registered') {
            $registered = 0;
            last;
        }
    }
    return $registered;
}

=head2 ipaddr2_registeration_set

    ipaddr2_registeration_set(id => 1, scc_code => '1234567890');

Register the image. Notice that this library also support registration through
ipaddr2_azure_deployment

=over 3

=item B<id> - VM id where to install and configure the web server

=item B<scc_code> - registration code

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back

=cut

sub ipaddr2_registeration_set {
    my (%args) = @_;
    foreach (qw(id scc_code)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    ipaddr2_ssh_internal(
        id => $args{id},
        cmd => 'sudo registercloudguest --clean',
        bastion_ip => $args{bastion_ip});

    ipaddr2_ssh_internal(
        id => $args{id},
        cmd => "sudo registercloudguest --force-new -r \"$args{scc_code}\"",
        bastion_ip => $args{bastion_ip});
}

=head2 ipaddr2_configure_web_server

    ipaddr2_configure_web_server(id => 1);

This function is in charge to:
    1. install the nginx package
    2. create a web page file
    3. enable and start the system

=over 2

=item B<id> - VM id where to install and configure the web server

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back

=cut

sub ipaddr2_configure_web_server {
    my (%args) = @_;
    croak("Argument < id > missing") unless $args{id};
    my @nginx_cmds = (
        'sudo zypper install -y nginx',
        'echo "I am $(hostname)" > /tmp/index.html',
        'sudo cp /tmp/index.html /srv/www/htdocs/index.html',
        'sudo systemctl enable --now nginx.service');
    $args{bastion_ip} //= ipaddr2_bastion_pubip();
    ipaddr2_ssh_internal(id => $args{id},
        cmd => $_,
        timeout => 240,
        bastion_ip =>
          $args{bastion_ip}) for (@nginx_cmds);
}

=head2 ipaddr2_refresh_repo

    ipaddr2_refresh_repo(id => 1);

Call zypper refresh

=over 1

=item B<id> - VM id where to install and configure the web server

=back

=cut

sub ipaddr2_refresh_repo {
    my (%args) = @_;
    croak("Argument < id > missing") unless $args{id};

    $args{bastion_ip} //= ipaddr2_bastion_pubip();
    ipaddr2_ssh_internal(id => $args{id},
        cmd => 'sudo zypper ref',
        timeout => 240,
        bastion_ip =>
          $args{bastion_ip});
}

=head2 ipaddr2_deployment_logs

    ipaddr2_deployment_logs()

Collect logs from the cloud infrastructure
=cut

sub ipaddr2_deployment_logs {
    my @diagnostic_log_files = az_vm_diagnostic_log_get(
        resource_group => ipaddr2_azure_resource_group());
    while (my $file = pop @diagnostic_log_files) {
        upload_logs($file, failok => 1);
    }
}

=head2 ipaddr2_destroy

    ipaddr2_destroy();

Destroy the deployment by deleting the resource group
=cut

sub ipaddr2_destroy {
    az_group_delete(name => ipaddr2_azure_resource_group(), timeout => 600);
}

=head2 ipaddr2_get_internal_vm_name

    my $vm_name = ipaddr2_get_internal_vm_name(id => 42);

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

    my $private_ip = ipaddr2_get_internal_vm_private_ip(id => 42);

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

=head2 ipaddr2_crm_move

    ipaddr2_crm_move(destination => 2);

move the rsc_web_00 resource to the indicated node

=over 3

=item B<destination> - VM id where to move the rsc_web_00 resource

=item B<id> - VM id where to run the command, not so important as long as it is in the cluster. Default 1.

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back

=cut

sub ipaddr2_crm_move {
    my (%args) = @_;
    croak("Argument < destination > missing") unless $args{destination};

    $args{bastion_ip} //= ipaddr2_bastion_pubip();
    $args{id} //= 1;

    my $cmd = join(' ',
        'sudo crm resource move',
        WEB_RSC,
        ipaddr2_get_internal_vm_name(id => $args{destination}));
    ipaddr2_ssh_internal(id => $args{id},
        cmd => $cmd,
        bastion_ip => $args{bastion_ip});
}

=head2 ipaddr2_crm_clear

    ipaddr2_crm_clear();

clear all location constrain used during the test

=over 2

=item B<id> - VM id where to run the command, not so important as long as it is in the cluster. Default 1.

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back

=cut

sub ipaddr2_crm_clear {
    my (%args) = @_;

    $args{bastion_ip} //= ipaddr2_bastion_pubip();
    $args{id} //= 1;

    my $cmd = join(' ',
        'sudo crm resource clear',
        WEB_RSC);
    ipaddr2_ssh_internal(id => $args{id},
        cmd => $cmd,
        bastion_ip => $args{bastion_ip});
}

=head2 ipaddr2_wait_for_takeover

    die "Takeover does not happens in time" unless  ipaddr2_wait_for_takeover(destination => 2);

Wait that web server is responding from the node indicated by id.
This check is implemented running a curl request from the bastion
and using the virtual IP address ar URL.
This is possible because the webserver on each node is configured 
to return its hostname in the response.
Return 1 as soon as it gets the id in the response. Return 0 if not within 10 minutes.

=over 2

=item B<destination> - VM id that from where the web server response is expected to come from

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back

=cut

sub ipaddr2_wait_for_takeover {
    my (%args) = @_;
    croak("Argument < destination > missing") unless $args{destination};

    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    my $counter = 0;
    my $dest_vm = ipaddr2_get_internal_vm_name(id => $args{destination});

    while ($counter < 60) {
        if (ipaddr2_get_web(
                bastion_ip => $args{bastion_ip},
                web_url => $frontend_ip,
                str_match => $dest_vm)) {
            record_info("TAKE_OVER", "Webserver now reply from $dest_vm");
            return 1;
        }
        sleep 10;
        $counter++;
    }
    return 0;
}

=head2 ipaddr2_get_web

    ipaddr2_get_web(str_match => 'openqa_vm_01');

Runs a curl request from the bastion and using the virtual IP address as URL.
Return result of searching str_match in the curl response

=over 3

=item B<web_url> - webserver url

=item B<str_match> - string to search in the curl output

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back

=cut

sub ipaddr2_get_web {
    my (%args) = @_;
    foreach (qw(web_url str_match)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    my $curl_ret = ipaddr2_ssh_bastion_script_output(
        bastion_ip => $args{bastion_ip},
        cmd => "curl -s http://$args{web_url}");

    return ($curl_ret =~ m/$args{str_match}/);
}

=head2 ipaddr2_test_master_vm

    ipaddr2_test_master_vm(id => 2);

Check the status on the VM that is supposed to have
the resources.

=over 2

=item B<id> - VM id that is expected to be master

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back

=cut

sub ipaddr2_test_master_vm {
    my (%args) = @_;
    croak("Argument < id > missing") unless $args{id};

    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    # checks on the cluster side
    ipaddr2_ssh_internal(id => $args{id},
        cmd => 'sudo crm status',
        bastion_ip => $args{bastion_ip});

    my $vm = ipaddr2_get_internal_vm_name(id => $args{id});
    my $res;
    foreach my $resource (qw(rsc_web_00 rsc_alb_00 rsc_ip_00)) {
        $res = ipaddr2_ssh_internal_output(
            id => $args{id},
            cmd => "sudo crm resource failcount $resource show $vm",
            bastion_ip => $args{bastion_ip});
        die "Fail count is not 0 for resource $resource in $vm" unless ($res =~ m/value=0/);

        $res = ipaddr2_ssh_internal_output(
            id => $args{id},
            cmd => "sudo crm resource locate $resource",
            bastion_ip => $args{bastion_ip});
        die "Resource $resource is not running on $vm" unless ($res =~ m/is running on: $vm/);
    }

    my $crm_configure = ipaddr2_ssh_internal_output(id => $args{id},
        cmd => 'sudo crm configure show',
        bastion_ip => $args{bastion_ip});

    my @preferred = $crm_configure =~ /cli-prefer-.*/g;
    die "Cluster has " . scalar @preferred . " resources with preferred location instead of expected 1"
      unless (scalar @preferred) eq 1;
    #ssh_node1 'sudo crm configure show' | grep -E "cli-prefer-.*${MYNAME}-vm-02" || test_die "Cluster should now have one cli-prefer- with ${MYNAME}-vm-02"

    # test that the web page is reachable from the bastion
    # using the Azure LB front end IP
    die "The web server is not running on $vm" unless ipaddr2_get_web(
        bastion_ip => $args{bastion_ip},
        web_url => $frontend_ip,
        str_match => $vm);
    # test that the web page is reachable from the bastion
    # using the VM hostname where the web server is supposed to run
    die "The web server is not running on $vm" unless ipaddr2_get_web(
        bastion_ip => $args{bastion_ip},
        web_url => $vm,
        str_match => $vm);

    my $ps_ret = ipaddr2_ssh_internal_output(
        id => $args{id},
        cmd => 'ps -xa',
        bastion_ip => $args{bastion_ip});
    die "Nginx process not running on $vm" unless ($ps_ret =~ m/nginx/);

    # check IP
    $res = ipaddr2_ssh_internal_output(
        id => $args{id},
        cmd => 'ip a show eth0',
        bastion_ip => $args{bastion_ip});
    die "VirtualIP $frontend_ip should be on $vm" unless ($res =~ m/$frontend_ip/);

    # Check if the master internal VM can ping the virtual IP
    ipaddr2_ssh_internal(
        id => $args{id},
        cmd => join(' ', $ping_cmd, $frontend_ip),
        bastion_ip => $args{bastion_ip});
}

=head2 ipaddr2_test_other_vm

    ipaddr2_test_other_vm(id => 1);

Check the status on the VM that is supposed not to have
the resources.

=over 2

=item B<id> - VM id that is expected not to be master

=item B<bastion_ip> - Public IP address of the bastion. Calculated if not provided.
                      Providing it as an argument is recommended in order
                      to avoid having to query Azure to get it.

=back

=cut

sub ipaddr2_test_other_vm {
    my (%args) = @_;
    croak("Argument < id > missing") unless $args{id};

    $args{bastion_ip} //= ipaddr2_bastion_pubip();

    # checks on the cluster side
    ipaddr2_ssh_internal(id => $args{id},
        cmd => 'sudo crm status',
        bastion_ip => $args{bastion_ip});

    my $vm = ipaddr2_get_internal_vm_name(id => $args{id});
    my $res;
    foreach my $resource (qw(rsc_web_00 rsc_alb_00 rsc_ip_00)) {
        $res = ipaddr2_ssh_internal_output(
            id => $args{id},
            cmd => "sudo crm resource locate $resource",
            bastion_ip => $args{bastion_ip});
        die "Resource $resource is running on $vm and should not" if ($res =~ m/is running on: $vm/);
    }
}

1;
