# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Library wrapper around some aws cli commands.

package sles4sap::aws_cli;
use strict;
use warnings FATAL => 'all';
use testapi;
use Carp qw(croak);
use Exporter qw(import);
use utils;


=head1 SYNOPSIS

Library to compose and run AWS cli commands.
=cut

our @EXPORT = qw(
  aws_import_key_pair
  aws_create_vpc
  aws_get_vpc_id
  aws_create_security_group
  aws_get_security_group_id
  aws_create_subnet
  aws_get_subnet_id
  aws_create_internet_gateway
  aws_get_internet_gateway_id
  aws_attach_internet_gateway
  aws_create_route_table
  aws_associate_route_table
  aws_create_route
  aws_authorize_security_group_ingress
  aws_create_vm
  aws_get_vm_id
  aws_wait_instance_status_ok
  aws_get_ip_address
);


=head2 aws_import_key_pair

    aws_import_key_pair($ssh_key, $pub_key_path);

Import an SSH public key pair into AWS EC2 for instance authentication

=over

=item B<$ssh_key> - name to assign to the imported key pair in AWS

=item B<$pub_key_path> - filesystem path to the public key file

=back
=cut

sub aws_import_key_pair {
    my ($ssh_key, $pub_key_path) = @_;
    assert_script_run("aws ec2 import-key-pair --key-name '$ssh_key' --public-key-material fileb://$pub_key_path");
}

=head2 aws_create_vpc

    my $vpc_id = aws_create_vpc($region, $cidr, $job_id);

Create a new AWS VPC with a specified CIDR block and tag it with the OpenQA job ID

=over

=item B<$region> - AWS region where to create the VPC

=item B<$cidr> - CIDR block for the VPC (e.g., '10.0.0.0/16')

=item B<$job_id> - OpenQA job identifier for tagging

=back

Returns the VPC ID
=cut

sub aws_create_vpc {
    my ($region, $cidr, $job_id) = @_;
    my $vpc_id = script_output("aws ec2 create-vpc --region $region --cidr-block $cidr --query 'Vpc.VpcId' --output text");
    die('VPC creation failed: VPC ID is empty') unless $vpc_id;
    assert_script_run("aws ec2 create-tags --resources $vpc_id --tags Key=OpenQAJobVpc,Value=$job_id --region $region");
    return $vpc_id;
}

=head2 aws_get_vpc_id

    my $vpc_id = aws_get_vpc_id($region, $job_id);

Retrieve the VPC ID associated with a specific OpenQA job

=over

=item B<$region> - AWS region where the VPC is located

=item B<$job_id> - OpenQA job identifier used to tag the VPC

=back

Returns the VPC ID
=cut

sub aws_get_vpc_id {
    my ($region, $job_id) = @_;
    return script_output(
        "aws ec2 describe-vpcs --filters 'Name=tag:OpenQAJobVpc,Values=$job_id'" .
          " --region $region --query 'Vpcs[0].VpcId' --output text");
}

=head2 aws_create_security_group

    my $sg_id = aws_create_security_group($region, $group_name, $description, $vpc_id);

Create an AWS security group within a VPC and tag it with the OpenQA job ID

=over

=item B<$region> - AWS region where to create the security group

=item B<$group_name> - name for the security group

=item B<$description> - description of the security group purpose

=item B<$vpc_id> - ID of the VPC where the security group will be created

=item B<$job_id> - OpenQA job identifier used to tag the VPC

=back

Returns the security group ID
=cut

sub aws_create_security_group {
    my ($region, $group_name, $description, $vpc_id, $job_id) = @_;
    my $sg_id = script_output(
        "aws ec2 create-security-group --region $region --group-name $group_name " .
          "--description '$description' --vpc-id $vpc_id --query 'GroupId' --output text"
    );
    die('Security group creation failed: SG ID is empty') unless $sg_id;
    assert_script_run("aws ec2 create-tags --resources $sg_id --tags Key=OpenQAJobSg,Value=$job_id --region $region");
    return $sg_id;
}

=head2 aws_get_security_group_id

    my $sg_id = aws_get_security_group_id($region, $job_id);

Retrieve the security group ID associated with a specific OpenQA job

=over

=item B<$region> - AWS region where the security group is located

=item B<$job_id> - OpenQA job identifier used to tag the security group

=back

Returns the security group ID
=cut

sub aws_get_security_group_id {
    my ($region, $job_id) = @_;
    return script_output(
        "aws ec2 describe-security-groups --filters 'Name=tag:OpenQAJobSg,Values=$job_id' --region $region" .
          " --query 'SecurityGroups[0].GroupId' --output text");
}

=head2 aws_create_subnet

    my $subnet_id = aws_create_subnet($region, $cidr, $vpc_id);

Create a subnet within a VPC with a specified CIDR block and tag it with the OpenQA job ID

=over

=item B<$region> - AWS region where to create the subnet

=item B<$cidr> - CIDR block for the subnet (e.g., '10.0.1.0/24')

=item B<$vpc_id> - ID of the VPC where the subnet will be created

=item B<$job_id> - OpenQA job identifier used to tag the security group

=back

Returns the subnet ID
=cut

sub aws_create_subnet {
    my ($region, $cidr, $vpc_id, $job_id) = @_;
    my $subnet_id = script_output(
        "aws ec2 create-subnet --region $region --cidr-block $cidr --vpc-id $vpc_id --query 'Subnet.SubnetId' --output text");
    die('Subnet creation failed: Subnet ID is empty') unless $subnet_id;
    assert_script_run("aws ec2 create-tags --resources $subnet_id --tags Key=OpenQAJobSubnet,Value=$job_id --region $region");
    return $subnet_id;
}

=head2 aws_get_subnet_id

    my $subnet_id = aws_get_subnet_id($region, $job_id);

Retrieve the subnet ID associated with a specific OpenQA job

=over

=item B<$region> - AWS region where the subnet is located

=item B<$job_id> - OpenQA job identifier used to tag the subnet

=back

Returns the subnet ID
=cut

sub aws_get_subnet_id {
    my ($region, $job_id) = @_;
    return script_output(
        "aws ec2 describe-subnets --filters 'Name=tag:OpenQAJobSubnet,Values=$job_id' --region $region --query 'Subnets[0].SubnetId' --output text");
}

=head2 aws_create_internet_gateway

    my $igw_id = aws_create_internet_gateway($region);

Create an internet gateway and tag it with the OpenQA job ID

=over

=item B<$region> - AWS region where to create the internet gateway

=item B<$job_id> - OpenQA job identifier used to tag the security group

=back

Returns the internet gateway ID
=cut

sub aws_create_internet_gateway {
    my ($region, $job_id) = @_;
    my $igw_id = script_output("aws ec2 create-internet-gateway --region $region --query 'InternetGateway.InternetGatewayId' --output text", 60);
    assert_script_run("aws ec2 create-tags --resources $igw_id --tags Key=OpenQAJobIgw,Value=$job_id --region $region");
    return $igw_id;
}

=head2 aws_get_internet_gateway_id

    my $igw_id = aws_get_internet_gateway_id($region, $job_id);

Retrieve the internet gateway ID associated with a specific OpenQA job

=over

=item B<$region> - AWS region where the internet gateway is located

=item B<$job_id> - OpenQA job identifier used to tag the internet gateway

=back

Returns the internet gateway ID
=cut

sub aws_get_internet_gateway_id {
    my ($region, $job_id) = @_;
    return script_output(
        "aws ec2 describe-internet-gateways --filters 'Name=tag:OpenQAJobIgw,Values=$job_id' --region $region" .
          " --query 'InternetGateways[0].InternetGatewayId' --output text");
}

=head2 aws_attach_internet_gateway

    aws_attach_internet_gateway($vpc_id, $igw_id, $region);

Attach an internet gateway to a VPC

=over

=item B<$vpc_id> - ID of the VPC to attach the gateway to

=item B<$igw_id> - ID of the internet gateway to attach

=item B<$region> - AWS region where the resources are located

=back
=cut

sub aws_attach_internet_gateway {
    my ($vpc_id, $igw_id, $region) = @_;
    assert_script_run("aws ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $igw_id --region $region");
}

=head2 aws_create_route_table

    my $route_table_id = aws_create_route_table($region, $vpc_id);

Create a route table within a VPC

=over

=item B<$region> - AWS region where to create the route table

=item B<$vpc_id> - ID of the VPC where the route table will be created

=back

Returns the route table ID
=cut

sub aws_create_route_table {
    my ($region, $vpc_id) = @_;
    return script_output("aws ec2 create-route-table --vpc-id $vpc_id --region $region --query 'RouteTable.RouteTableId' --output text", 180);
}

=head2 aws_associate_route_table

    aws_associate_route_table($subnet_id, $route_table_id, $region);

Associate a route table with a subnet

=over

=item B<$subnet_id> - ID of the subnet to associate

=item B<$route_table_id> - ID of the route table to associate

=item B<$region> - AWS region where the resources are located

=back
=cut

sub aws_associate_route_table {
    my ($subnet_id, $route_table_id, $region) = @_;
    assert_script_run(
        "aws ec2 associate-route-table --subnet-id $subnet_id --route-table-id $route_table_id" .
          " --region $region --query 'AssociationId' --output text");
}

=head2 aws_create_route

    aws_create_route($route_table_id, $destination_cidr_block, $igw_id, $region);

Create a route in a route table pointing to an internet gateway

=over

=item B<$route_table_id> - ID of the route table where to create the route

=item B<$destination_cidr_block> - destination CIDR block for the route (e.g., '0.0.0.0/0' for default route)

=item B<$igw_id> - ID of the internet gateway as the route target

=item B<$region> - AWS region where the resources are located

=back
=cut

sub aws_create_route {
    my ($route_table_id, $destination_cidr_block, $igw_id, $region) = @_;
    assert_script_run(
        "aws ec2 create-route --route-table-id $route_table_id --destination-cidr-block $destination_cidr_block" .
          " --gateway-id $igw_id --region $region");
}

=head2 aws_authorize_security_group_ingress

    aws_authorize_security_group_ingress($sg_id, $protocol, $port, $cidr, $region);

Add an ingress rule to a security group allowing traffic from a specific CIDR block

=over

=item B<$sg_id> - ID of the security group to modify

=item B<$protocol> - protocol for the rule (e.g., 'tcp', 'udp', 'icmp')

=item B<$port> - port number or port range for the rule

=item B<$cidr> - CIDR block allowed to access (e.g., '0.0.0.0/0' for all)

=item B<$region> - AWS region where the security group is located

=back
=cut

sub aws_authorize_security_group_ingress {
    my ($sg_id, $protocol, $port, $cidr, $region) = @_;
    assert_script_run(
        "aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol $protocol --port $port --cidr $cidr --region $region");
}

=head2 aws_create_vm

    my $instance_id = aws_create_vm($instance_type, $image_name, $subnet_id, $sg_id, $ssh_key, $region);

Launch an EC2 instance with specified configuration and tag it with the OpenQA job ID

=over

=item B<$instance_type> - EC2 instance type (e.g., 't2.micro', 'm5.large')

=item B<$image_name> - Name to use for the instance

=item B<$subnet_id> - ID of the subnet where to launch the instance

=item B<$sg_id> - ID of the security group to assign to the instance

=item B<$ssh_key> - name of the SSH key pair for instance access

=item B<$region> - AWS region where to launch the instance

=item B<$job_id> - OpenQA job identifier used to tag the internet gateway

=back

Returns the instance ID
=cut

sub aws_create_vm {
    my ($instance_type, $image_name, $subnet_id, $sg_id, $ssh_key, $region, $job_id) = @_;

    # 679593333241 ( aws-marketplace )
    my $ownerId = get_var('PUBLIC_CLOUD_EC2_ACCOUNT_ID', '679593333241');
    my $image_id = script_output(join(' ',
            'aws ec2 describe-images',
            "--filters 'Name=name,Values=" . $image_name . "-*'",
            "--owners '$ownerId'",
            "--query 'Images[?Name != `ecs`]|[0].ImageId'",
            '--output=text'), 240);

    die("Image name:$image_name Owner:$ownerId --> Image ID:$image_id") if ($image_id eq 'None');
    return script_output(join(' ',
            'aws ec2 run-instances',
            "--image-id $image_id",
            '--count 1',
            "--subnet-id $subnet_id",
            '--associate-public-ip-address',
            "--security-group-ids $sg_id",
            "--instance-type $instance_type",
            "--tag-specifications 'ResourceType=instance,Tags=[{Key=OpenQAJobVm,Value='$job_id'}]'",
            "--query 'Instances[0].InstanceId'",
            "--key-name $ssh_key",
            '--output text'), 240);
}

=head2 aws_get_vm_id

    my $instance_id = aws_get_vm_id($region, $job_id);

Retrieve the EC2 instance ID associated with a specific OpenQA job

=over

=item B<$region> - AWS region where the instance is located

=item B<$job_id> - OpenQA job identifier used to tag the instance

=back

Returns the instance ID
=cut

sub aws_get_vm_id {
    my ($region, $job_id) = @_;
    return script_output(
        "aws ec2 describe-instances --filters 'Name=tag:OpenQAJobVm,Values=$job_id' " .
          "--query 'Reservations[*].Instances[*].InstanceId' --output text --region $region");
}

=head2 aws_wait_instance_status_ok

    aws_wait_instance_status_ok($instance_id);

Wait for an EC2 instance to reach 'running' state with a timeout of 600 seconds

=over

=item B<$instance_id> - ID of the instance to monitor

=back
=cut

sub aws_wait_instance_status_ok {
    my ($instance_id) = @_;
    script_retry(
        "aws ec2 describe-instances --instance-ids $instance_id" .
          " --query 'Reservations[*].Instances[*].State.Name' --output text | grep 'running'", 90, delay => 15, retry => 12);
}

=head2 aws_get_ip_address

    my $ip = aws_get_ip_address($instance_id);

Retrieve the public IP address of an EC2 instance

=over

=item B<$instance_id> - ID of the instance

=back

Returns the public IP address
=cut

sub aws_get_ip_address {
    my ($instance_id) = @_;
    return script_output("aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[0].Instances[0].PublicIpAddress' --output text", 90);
}

1;
