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
use version_utils qw(is_sle);

=head1 SYNOPSIS

Library to manage cloud crash tests
=cut

our @EXPORT = qw(
  crash_deploy_azure
  crash_deploy_aws
  crash_pubip
  crash_system_ready
  crash_softrestart
  crash_destroy_azure
  crash_destroy_aws
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
    else {
        die "Not supported provider '$args{provider}'";
    }
    return $vm_ip;
}


=head2 crash_system_ready

    Polls C<systemctl is-system-running> via SSH for up to 5 minutes.
    If C<reg_code> is provided, registers the system using C<registercloudguest> and verifies with C<SUSEConnect -s>.

=over

=item B<reg_code> Registration code.

=item B<ssh_command> SSH command for registration.

=back
=cut

sub crash_system_ready(%args) {
    croak "Missing mandatory argument 'ssh_command'" unless $args{ssh_command};
    my $ret;

    my $start_time = time();
    while ((time() - $start_time) < 300) {
        $ret = script_run(join(' ', $args{ssh_command}, 'sudo', 'systemctl is-system-running'));
        last unless $ret;
        sleep 10;
    }
    return unless ($args{reg_code});

    script_run(join(' ', $args{ssh_command}, 'sudo SUSEConnect -s'), 200);
    script_run(join(' ', $args{ssh_command}, 'sudo registercloudguest --clean'), 200);

    my $rc = 1;
    my $attempt = 0;

    while ($rc != 0 && $attempt < 4) {
        $rc = script_run("$args{ssh_command} sudo registercloudguest --force-new -r $args{reg_code} -e testing\@suse.com", 600);
        record_info('REGISTER CODE', $rc);
        $attempt++;
    }
    die "registercloudguest failed after $attempt attempts with exit $rc" unless ($rc == 0);
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
    my $job_id = crash_deploy_name();

    my $instance_id = aws_vm_get_id(region => $args{region}, job_id => $job_id);
    my $vpc_id = aws_vpc_get_id(region => $args{region}, job_id => $job_id);

    # Terminate instance and wait
    aws_vm_terminate(region => $args{region}, instance_id => $instance_id);

    # Delete all resources
    aws_security_group_delete(region => $args{region}, job_id => $job_id);
    aws_subnet_delete(region => $args{region}, job_id => $job_id);

    aws_internet_gateway_delete(
        vpc_id => $vpc_id,
        job_id => $job_id,
        region => $args{region});
    aws_route_table_delete(region => $args{region}, vpc_id => $vpc_id);

    # Delete everything else (AWS handles dependencies automatically if we wait)
    aws_vpc_delete(region => $args{region}, vpc_id => $vpc_id);
}

1;
