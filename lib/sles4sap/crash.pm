# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Library sub and shared data for the crash cloud test.

package sles4sap::crash;

use strict;
use warnings FATAL => 'all';
use Mojo::Base -signatures;
use testapi;
use mmapi qw( get_current_job_id );
use Carp qw( croak );
use Exporter qw(import);
use sles4sap::azure_cli;
use sles4sap::aws_cli;
use sles4sap::gcp_cli;
use version_utils qw(is_sle);

=head1 SYNOPSIS

Library to manage cloud crash tests
=cut

our @EXPORT = qw(
  crash_deploy_azure
  crash_deploy_aws
  crash_deploy_gcp
  crash_pubip
  crash_get_username
  crash_get_instance
  crash_cleanup
  crash_system_ready
  crash_softrestart
  crash_wait_back
  crash_destroy_azure
  crash_destroy_aws
  crash_destroy_gcp
);

use constant DEPLOY_PREFIX => 'crash';
use constant USER => 'cloudadmin';
use constant SSH_KEY_ID => 'id_rsa';

=head2 crash_deploy_name

    my $name = crash_deploy_name();

Return the deploy name. Azure use it as resource group name

=cut

sub crash_deploy_name {
    return DEPLOY_PREFIX . get_current_job_id();
}

=head2 crash_deploy_azure

Run the Azure deployment for the crash test

=over

=item B<region> - existing resource group

=item B<os> - existing Load balancer NAME

=back
=cut

sub crash_deploy_azure(%args) {
    foreach (qw(region os)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $rg = crash_deploy_name();
    az_group_create(name => $rg, region => $args{region});

    my $os_ver;
    if ($args{os} =~ /\.vhd$/) {
        my $img_name = $rg . 'img';
        az_img_from_vhd_create(
            resource_group => $rg,
            name => $img_name,
            source => $args{os});
        $os_ver = $img_name;
    }
    else {
        $os_ver = $args{os};
    }

    my $nsg = DEPLOY_PREFIX . '-nsg';
    az_network_nsg_create(resource_group => $rg, name => $nsg);
    az_network_nsg_rule_create(resource_group => $rg, nsg => $nsg, name => $nsg . 'RuleSSH', port => 22);

    my $pub_ip_name = DEPLOY_PREFIX . '-pub_ip';
    az_network_publicip_create(resource_group => $rg, name => $pub_ip_name, zone => '1 2 3');

    my $vnet = DEPLOY_PREFIX . '-vnet';
    my $subnet = DEPLOY_PREFIX . '-snet';
    az_network_vnet_create(
        resource_group => $rg,
        region => $args{region},
        vnet => $vnet,
        address_prefixes => '10.1.0.0/16',
        snet => $subnet,
        subnet_prefixes => '10.1.0.0/24');

    my $nic = DEPLOY_PREFIX . '-nic';
    az_nic_create(
        resource_group => $rg,
        name => $nic,
        vnet => $vnet,
        subnet => $subnet,
        nsg => $nsg,
        pubip_name => $pub_ip_name);

    my %vm_create_args = (
        resource_group => $rg,
        name => DEPLOY_PREFIX . '-vm',
        image => $os_ver,
        nic => $nic,
        username => USER,
        region => $args{region});
    $vm_create_args{security_type} = 'Standard' if is_sle('<=12-SP5');
    $vm_create_args{timeout} = 1200;
    az_vm_create(%vm_create_args);

    az_vm_wait_running(
        resource_group => crash_deploy_name(),
        name => DEPLOY_PREFIX . '-vm',
        timeout => 1200);
}

=head2 crash_deploy_aws

Run the AWS deployment for the crash test
Returns the instance ID

=over

=item B<region> - existing resource group

=item B<image_name> - OS image name

=item B<image_owner> - OS image owner

=item B<instance_type> - Instance type of the VM

=item B<ssh_pub_key> - ssh public key to be uploaded in the VM 

=back
=cut

sub crash_deploy_aws(%args) {
    foreach (qw(region image_name image_owner ssh_pub_key instance_type)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $job_id = crash_deploy_name();

    my $ssh_key = 'openqa-cli-test-key-' . crash_deploy_name();
    aws_ssh_key_pair_import(ssh_key => $ssh_key, pub_key_path => $args{ssh_pub_key});

    my $vpc_id = aws_vpc_create(region => $args{region}, cidr => "10.0.0.0/28", job_id => $job_id);
    my $sg_id = aws_security_group_create(
        region => $args{region},
        group_name => 'crash-aws',
        description => 'crash aws security group',
        vpc_id => $vpc_id,
        job_id => $job_id);

    my $subnet_id = aws_subnet_create(
        region => $args{region},
        cidr => '10.0.0.0/28',
        vpc_id => $vpc_id,
        job_id => $job_id);

    my $igw_id = aws_internet_gateway_create(region => $args{region}, job_id => $job_id);
    aws_internet_gateway_attach(vpc_id => $vpc_id, igw_id => $igw_id, region => $args{region});

    # SSH connection
    my $route_table_id = aws_route_table_create(region => $args{region}, vpc_id => $vpc_id);

    aws_route_table_associate(subnet_id => $subnet_id, route_table_id => $route_table_id, region => $args{region});

    aws_route_create(
        route_table_id => $route_table_id,
        destination_cidr_block => "0.0.0.0/0",
        igw_id => $igw_id,
        region => $args{region});

    aws_security_group_authorize_ingress(
        sg_id => $sg_id,
        protocol => 'tcp',
        port => 22,
        cidr => "0.0.0.0/0",
        region => $args{region});

    #create vm
    my $instance_id = aws_vm_create(
        instance_type => $args{instance_type},
        image_name => $args{image_name},
        owner => $args{image_owner},
        subnet_id => $subnet_id,
        sg_id => $sg_id,
        ssh_key => $ssh_key,
        region => $args{region},
        job_id => $job_id);
    aws_vm_wait_status_ok(instance_id => $instance_id);
    return $instance_id;
}

=head2 crash_deploy_gcp

Run the GCP deployment for the crash test

=over

=item B<region> - GCP region

=item B<zone> - GCP zone (e.g., 'us-central1-a')

=item B<project> - GCP project ID

=item B<version> - OS version

=item B<image_project> - image project name

=item B<machine_type> - machine type (e.g., 'n1-standard-2')

=item B<ssh_key> - ssh_key file

=back
=cut

sub crash_deploy_gcp(%args) {
    foreach (qw(region zone project image image_project version machine_type ssh_key)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $job_id = crash_deploy_name();
    my $region = $args{region};

    my $network_name = $job_id . '-network';
    gcp_network_create(
        project => $args{project},
        name => $network_name);

    my $subnet_name = $job_id . '-subnet';
    gcp_subnet_create(
        project => $args{project},
        region => $region,
        name => $subnet_name,
        network => $network_name,
        cidr => '10.0.0.0/24');

    my $firewall_name = $job_id . '-allow-ssh';
    gcp_firewall_rule_create(
        project => $args{project},
        name => $firewall_name,
        network => $network_name,
        port => 22);

    my $ip_name = $job_id . '-ip';
    gcp_external_ip_create(
        project => $args{project},
        region => $region,
        name => $ip_name);

    my $vm_name = $job_id . '-vm';
    gcp_vm_create(
        project => $args{project},
        zone => $args{zone},
        name => $vm_name,
        image => $args{image},
        image_project => $args{image_project},
        machine_type => $args{machine_type},
        network => $network_name,
        subnet => $subnet_name,
        address => $ip_name,
        ssh_key => $args{ssh_key},
        timeout => 1200);

    gcp_vm_wait_running(
        zone => $args{zone},
        name => $vm_name,
        timeout => 1200);
}

=head2 crush_pubip

Get the deployment public IP of the VM. Die if an
unsupported csp name is provided.

=over

=item B<provider> - Cloud provider name using same format of PUBLIC_CLOUD_PROVIDER setting

=item B<region> deployment region

=back
=cut

sub crash_pubip(%args) {
    foreach (qw(region provider)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    my $vm_ip = '';
    if ($args{provider} eq 'EC2') {
        $vm_ip = aws_get_ip_address(
            instance_id => aws_vm_get_id(region => $args{region}, job_id => crash_deploy_name()));
    }
    elsif ($args{provider} eq 'AZURE') {
        $vm_ip = az_network_publicip_get(
            resource_group => crash_deploy_name(),
            name => DEPLOY_PREFIX . "-pub_ip");
    }
    elsif ($args{provider} eq 'GCE') {
        my $zone = $args{region} . '-' . get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE');
        $vm_ip = gcp_public_ip_get(
            zone => $zone,
            name => crash_deploy_name() . '-vm');
    }
    else {
        die "Not supported provider '$args{provider}'";
    }
    return $vm_ip;
}

=head2 crash_get_username

    my $username = crash_get_username(provider => 'GCE');

Get the username for SSH login based on cloud provider

=over

=item B<provider> - Cloud provider name (EC2, AZURE, GCE)

=back
=cut

sub crash_get_username(%args) {
    croak("Argument < provider > missing") unless $args{provider};

    my %usernames = (
        GCE => 'cloudadmin',
        AZURE => 'cloudadmin',
        EC2 => 'ec2-user',
    );

    die "Unsupported cloud provider: $args{provider}" unless $usernames{$args{provider}};
    return $usernames{$args{provider}};
}

=head2 crash_get_instance

    my $instance = crash_get_instance(
        provider => 'GCE',
        region => 'us-central1');

Create and return a publiccloud::instance object for the crash test VM

=over

=item B<provider> - Cloud provider name (EC2, AZURE, GCE)

=item B<region> - Cloud region

=back
=cut

sub crash_get_instance(%args) {
    foreach (qw(provider region)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $vm_ip = crash_pubip(provider => $args{provider}, region => $args{region});
    my $username = crash_get_username(provider => $args{provider});

    require publiccloud::instance;
    my $instance = publiccloud::instance->new(
        public_ip => $vm_ip,
        username => $username
    );

    return $instance;
}

=head2 crash_cleanup

    crash_cleanup(
        provider => 'GCE',
        region => 'us-central1');

Clean up cloud resources for crash test

=over

=item B<provider> - Cloud provider name (EC2, AZURE, GCE)

=item B<region> - Cloud region

=back
=cut

sub crash_cleanup(%args) {
    foreach (qw(provider region)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    if ($args{provider} eq 'AZURE') {
        crash_destroy_azure();
    }
    elsif ($args{provider} eq 'EC2') {
        crash_destroy_aws(region => $args{region});
    }
    elsif ($args{provider} eq 'GCE') {
        my $zone = $args{region} . '-' . get_required_var('PUBLIC_CLOUD_AVAILABILITY_ZONE');
        crash_destroy_gcp(zone => $zone, region => $args{region});
    }
    else {
        die "Unsupported provider: $args{provider}";
    }
}

=head2 crash_system_ready

    Polls C<systemctl is-system-running> via SSH for up to 5 minutes.
    If C<reg_code> is provided, registers the system and verifies with C<SUSEConnect -s>.

=over

=item B<reg_code> Registration code.

=item B<ssh_command> SSH command for registration.

=item B<scc_endpoint> The way of doing registration, SUSEConnect or registercloudguest.

=back
=cut

sub crash_system_ready(%args) {
    croak "Missing mandatory argument 'ssh_command'" unless $args{ssh_command};
    $args{scc_endpoint} //= 'registercloudguest';

    my $ret;

    my $start_time = time();
    while ((time() - $start_time) < 300) {
        $ret = script_run(join(' ', $args{ssh_command}, 'sudo', 'systemctl is-system-running'));
        last unless $ret;
        sleep 10;
    }
    return unless ($args{reg_code});

    script_run(join(' ', $args{ssh_command}, 'sudo SUSEConnect -s'), 200);
    script_run(join(' ', $args{ssh_command}, "sudo $args{scc_endpoint} --clean"), 200);

    my $rc = 1;
    my $attempt = 0;

    my $forcenew = ($args{scc_endpoint} eq 'registercloudguest') ? '--force-new' : '';

    while ($rc != 0 && $attempt < 4) {
        $rc = script_run("$args{ssh_command} sudo $args{scc_endpoint} $forcenew -r $args{reg_code} -e testing\@suse.com", 600);
        record_info('REGISTER CODE', $rc);
        $attempt++;
    }
    die "Registration failed after $attempt attempts with exit $rc" unless ($rc == 0);
    assert_script_run(join(' ', $args{ssh_command}, 'sudo SUSEConnect -s'));
}


=head2 crash_softrestart

    crash_softrestart(instance => $instance [, timeout => 600]);

Does a soft restart of the given C<instance> by running the command C<shutdown -r>.

=over

=item B<instance> instance of the PC class.

=item B<timeout>

=back
=cut

sub crash_softrestart(%args) {
    croak "Missing mandatory argument 'instance'" unless $args{instance};
    $args{timeout} //= 600;

    $args{instance}->ssh_assert_script_run(
        cmd => 'sudo /sbin/shutdown -r +1',
        ssh_opts => '-o StrictHostKeyChecking=no');
    sleep 60;

    my $start_time = time();
    # wait till ssh disappear
    my $out = $args{instance}->wait_for_ssh(
        timeout => $args{timeout},
        wait_stop => 1,
        'cloudadmin');
    # ok ssh port closed
    record_info("Shutdown failed",
        "WARNING: while stopping the system, ssh port still open after timeout,\nreporting: $out")
      if (defined $out);    # not ok port still open

    my $shutdown_time = time() - $start_time;
    $args{instance}->wait_for_ssh(
        timeout => $args{timeout} - $shutdown_time,
        'cloudadmin',
        0);
}

=head2 crash_wait_back

  crash_wait_back(vm_ip => '1.2.3.4');

Wait until SUT is back again polling port 22 on the given IP.
Then list for failed services and die if find one.

=over

=item B<vm_ip> Public IP address of the SUT, can be calculated by crash_pubip

=item B<username> Public IP address of the SUT, can be calculated by crash_pubip

=back
=cut

sub crash_wait_back(%args) {
    foreach (qw(vm_ip username)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $done = 0;
    my $start_time = time();
    while ((time() - $start_time) < 300) {
        my $exit_code = script_run('nc -vz -w 1 ' . $args{vm_ip} . ' 22', quiet => 1);
        if ($exit_code == 0) {
            $done = 1;
            last;
        }
        sleep 10;
    }
    die "No reply from $args{vm_ip}" unless ($done);

    my $services_output = script_output(join(' ',
            'ssh',
            '-F /dev/null',
            '-o ControlMaster=no',
            '-o StrictHostKeyChecking=no',
            '-o UserKnownHostsFile=/dev/null',
            $args{username} . '@' . $args{vm_ip},
            'sudo systemctl --failed --no-pager --plain'), 100);
    my @failed_units = grep { /^\S+\.(service|socket|target|mount|timer)\s/ } split /\n/, $services_output;
    record_info('Failed services', 'Status : ' . join(' ', @failed_units));
    die "Found failed services:\n$services_output" if @failed_units;
}

=head2 crash_destroy_azure

Delete the Azure deployment

=cut

sub crash_destroy_azure {
    my $rg = crash_deploy_name();
    record_info('AZURE CLEANUP', "Deleting resource group: $rg");
    az_group_delete(name => $rg, timeout => 360);
}


=head2 crash_destroy_aws

Delete the AWS deployment

=over

=item B<region> region where the deployment has been deployed in AWS

=back
=cut

sub crash_destroy_aws(%args) {
    croak "Missing mandatory argument 'region'" unless $args{region};
    my %ret;
    my $job_id = crash_deploy_name();

    my $instance_id = aws_vm_get_id(region => $args{region}, job_id => $job_id);
    my $vpc_id = aws_vpc_get_id(region => $args{region}, job_id => $job_id);

    # Terminate instance and wait
    $ret{vm} = aws_vm_terminate(region => $args{region}, instance_id => $instance_id);

    # Delete all resources
    $ret{sg} = aws_security_group_delete(region => $args{region}, job_id => $job_id);
    $ret{subnet} = aws_subnet_delete(region => $args{region}, job_id => $job_id);

    $ret{ig} = aws_internet_gateway_delete(
        vpc_id => $vpc_id,
        job_id => $job_id,
        region => $args{region});
    $ret{rt} = aws_route_table_delete(region => $args{region}, vpc_id => $vpc_id);

    # Delete everything else (AWS handles dependencies automatically if we wait)
    $ret{vpc} = aws_vpc_delete(region => $args{region}, vpc_id => $vpc_id);

    foreach my $key (keys %ret) {
        # return the first not zero
        return $ret{$key} if $ret{$key};
    }
    return 0;
}


=head2 crash_destroy_gcp

Delete the GCP deployment

=over

=item B<zone> - GCP zone where the deployment was created

=item B<region> - GCP region

=back
=cut

sub crash_destroy_gcp(%args) {
    foreach (qw(zone region)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my %ret;
    my $job_id = crash_deploy_name();
    my $region = $args{zone};
    $region =~ s/-[a-z]$//;

    record_info('GCP CLEANUP', "Deleting GCP resources for job: $job_id");

    $ret{vm} = gcp_vm_terminate(
        zone => $args{zone},
        name => $job_id . '-vm');

    $ret{ip} = gcp_external_ip_delete(
        region => $region,
        name => $job_id . '-ip');

    $ret{firewall} = gcp_firewall_rule_delete(
        name => $job_id . '-allow-ssh');

    $ret{subnet} = gcp_subnet_delete(
        region => $region,
        name => $job_id . '-subnet');

    $ret{network} = gcp_network_delete(
        name => $job_id . '-network');

    foreach my $key (keys %ret) {
        if ($ret{$key}) {
            record_info("Failure in $key", "Failed to destory $key");
            return $ret{$key};
        }
    }
    return 0;
}

1;
