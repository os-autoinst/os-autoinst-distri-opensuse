# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: This module is responsible for creating all necessary AWS resources:
# It saves VM public IP and SSH command into job variables

use base 'publiccloud::basetest';
use testapi;
use publiccloud::utils;
use mmapi 'get_current_job_id';
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;


sub run {
    my ($self) = @_;

    die('AWS is the only CSP supported for this test')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'EC2');

    my $aws_prefix = get_var('DEPLOY_PREFIX', 'clne');
    my $job_id = $aws_prefix . get_current_job_id();

    select_serial_terminal;

    my $provider = $self->provider_factory();

    my $os_ver;
    if (get_var('PUBLIC_CLOUD_IMAGE_LOCATION')) {
        $os_ver = $provider->get_blob_uri(get_var('PUBLIC_CLOUD_IMAGE_LOCATION'));
    } else {
        $os_ver = $provider->get_image_id();
    }

    record_info("OS", $os_ver);
    assert_script_run('rm ~/.ssh/config');
    my $ssh_key = "openqa-cli-test-key-$job_id";
    assert_script_run("aws ec2 import-key-pair --key-name '$ssh_key' --public-key-material fileb://" . $provider->ssh_key . ".pub");

    my $region = get_var('PUBLIC_CLOUD_REGION');
    my $vpc_id = script_output("aws ec2 create-vpc --region $region --cidr-block 10.0.0.0/28 --query 'Vpc.VpcId' --output text");
    my $sg_id = script_output(
        "aws ec2 create-security-group " .
          "--region $region " .
          "--group-name crash-aws " .
          "--description 'crash aws security group' " .
          "--vpc-id $vpc_id " .
          "--query 'GroupId' --output text"
    );
    my $subnet_id = script_output(
        "aws ec2 create-subnet " .
          "--region $region " .
          "--cidr-block 10.0.0.0/28 " .
          "--vpc-id $vpc_id --query 'Subnet.SubnetId' --output text");
    my $igw_id = script_output(
        "aws ec2 create-internet-gateway --region $region --query 'InternetGateway.InternetGatewayId' --output text", 60);
    assert_script_run("aws ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $igw_id --region $region");

    # SSH connection
    my $route_table_id = script_output("aws ec2 create-route-table " .
          "--vpc-id $vpc_id --region $region --query 'RouteTable.RouteTableId' --output text", 180);
    my $as_rt_id = script_output(
        "aws ec2 associate-route-table --subnet-id $subnet_id --route-table-id $route_table_id --region $region" .
          " --query 'AssociationId' --output text");
    assert_script_run("aws ec2 create-route --route-table-id $route_table_id --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id --region $region");
    assert_script_run("aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 22 --cidr 0.0.0.0/0");


    #create vm
    my $instance_id = script_output(
        "aws ec2 run-instances --image-id " . get_var('PUBLIC_CLOUD_IMAGE_ID') . " --count 1 --subnet-id $subnet_id --associate-public-ip-address " .
          "--security-group-ids $sg_id --instance-type " . get_var('PUBLIC_CLOUD_NEW_INSTANCE_TYPE') .
          " --query 'Instances[0].InstanceId' --key-name $ssh_key --output text", 240);
    script_retry("aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[*].Instances[*].State.Name' --output text | grep 'running'", 90, delay => 15, retry => 12);

    my $ip_address = script_output("aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[0].Instances[0].PublicIpAddress' --output text", 90);
    my $ssh_cmd = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user\@$ip_address";
    script_retry("$ssh_cmd hostnamectl", 90, delay => 15, retry => 12);
    set_var('VM_IP', $ip_address);
    set_var('SSH_CMD', $ssh_cmd);
    set_var('INS_ID', $instance_id);
    set_var('VPC_ID', $vpc_id);
    set_var('IGW', $igw_id);
    set_var('SG_ID', $sg_id);
    set_var('SUBNET', $subnet_id);
    record_info('Done', 'Test finished');
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
}

1;
