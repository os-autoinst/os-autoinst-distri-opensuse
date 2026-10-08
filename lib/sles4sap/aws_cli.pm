# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Library wrapper around some aws cli commands.

package sles4sap::aws_cli;
use strict;
use warnings FATAL => 'all';
use Mojo::Base -signatures;
use Mojo::JSON qw(decode_json);
use testapi;
use Carp qw(croak);
use Exporter qw(import);
use utils;


=head1 SYNOPSIS

Library to compose and run AWS cli commands.
=cut

our @EXPORT = qw(
  aws_vpc_create
  aws_vpc_get_id
  aws_vpc_delete
  aws_subnet_create
  aws_subnet_get_ids
  aws_subnet_delete
  aws_security_group_create
  aws_security_group_delete
  aws_security_group_get_id
  aws_security_group_authorize_ingress
  aws_internet_gateway_create
  aws_internet_gateway_get_id
  aws_internet_gateway_attach
  aws_internet_gateway_delete
  aws_route_table_create
  aws_route_table_associate
  aws_route_table_delete
  aws_route_create
  aws_vm_create
  aws_vm_get_id
  aws_vm_wait_status_ok
  aws_vm_terminate
  aws_get_ip_address
  aws_ssh_key_pair_import
  aws_tgw_vpc_attachment_get_id
  aws_tgw_get_id
  aws_vpc_get_subnets
  aws_vpc_get_routing_tables
  aws_tgw_attachment_create
  aws_tgw_attachment_delete
  aws_route_create_tgw
);


=head2 aws_vpc_create

    my $vpc_id = aws_vpc_create(
        region => 'us-west',
        cidr => '1.2.3/18',
        job_id => 'abc123456');

Create a new AWS VPC with a specified CIDR block and tag it with the OpenQA job ID
Returns the VPC ID

=over

=item B<region> - AWS region where to create the VPC

=item B<cidr> - CIDR block for the VPC (e.g., '10.0.0.0/16')

=item B<job_id> - OpenQA job identifier for tagging

=back
=cut

sub aws_vpc_create(%args) {
    foreach (qw(region cidr job_id)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $vpc_id = script_output(join(' ',
            'aws ec2 create-vpc',
            '--region', $args{region},
            '--cidr-block', $args{cidr},
            '--query Vpc.VpcId --output text'));
    die('VPC creation failed: VPC ID is empty') unless $vpc_id;
    assert_script_run(join(' ',
            'aws ec2 create-tags',
            '--resources', $vpc_id,
            "--tags Key=OpenQAJobVpc,Value=$args{job_id}",
            '--region', $args{region}));
    return $vpc_id;
}

=head2 aws_vpc_get_id

    my $vpc_id = aws_vpc_get_id(
        region => 'us-west',
        job_id => 'abc123456');

Retrieve the VPC ID associated with a specific OpenQA job
Returns the VPC ID

=over

=item B<region> - AWS region where the VPC is located

=item B<job_id> - OpenQA job identifier used to tag the VPC

=back
=cut

sub aws_vpc_get_id(%args) {
    foreach (qw(region job_id)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_output(join(' ',
            'aws ec2 describe-vpcs',
            "--filters 'Name=tag:OpenQAJobVpc,Values=$args{job_id}'",
            '--region', $args{region},
            "--query 'Vpcs[0].VpcId' --output text"));
}

=head2 aws_vpc_delete

    my $ret = aws_vpc_delete(
        region => 'us-west',
        vpc_id => 'vpc-456');

Delete the VPC, do not assert but return the exit code of the command.

=over

=item B<region> - AWS region where the VPC is located

=item B<vpc_id> - ID of the VPC to delete

=back
=cut

sub aws_vpc_delete(%args) {
    foreach (qw(region vpc_id)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_run(join(' ',
            'aws ec2 delete-vpc',
            '--vpc-id', $args{vpc_id},
            '--region', $args{region}));
}

=head2 aws_security_group_create

    my $sg_id = aws_security_group_create(
        region => 'uswest',
        group_name => 'something',
        description => 'be or not to be',
        vpc_id => 'vpc123456',
        job_is => '7890');

Create an AWS security group within a VPC and tag it with the OpenQA job ID

Returns the security group ID

=over

=item B<region> - AWS region where to create the security group

=item B<group_name> - name for the security group

=item B<description> - description of the security group purpose

=item B<vpc_id> - ID of the VPC where the security group will be created

=item B<job_id> - OpenQA job identifier used to tag the VPC

=back
=cut

sub aws_security_group_create(%args) {
    foreach (qw(region group_name description vpc_id job_id)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $sg_id = script_output(join(' ',
            'aws ec2 create-security-group',
            '--region', $args{region},
            '--group-name', $args{group_name},
            '--description', "'$args{description}'",
            '--vpc-id', $args{vpc_id},
            "--query 'GroupId' --output text"));
    die('Security group creation failed: SG ID is empty') unless $sg_id;
    assert_script_run("aws ec2 create-tags --resources $sg_id --tags Key=OpenQAJobSg,Value=$args{job_id} --region $args{region}");
    return $sg_id;
}

=head2 aws_security_group_delete

    my $ret = aws_security_group_delete(
        region => 'uswest',
        group_name => 'something',
        description => 'be or not to be',
        vpc_id => 'vpc123456',
        job_is => '7890');

Delete the security group, do not assert but return the exit code of the command.

=over

=item B<region> - AWS region where to create the security group

=item B<job_id> - OpenQA job identifier used to tag the VPC

=back
=cut

sub aws_security_group_delete(%args) {
    foreach (qw(region job_id)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_run(join(' ',
            'aws ec2 delete-security-group',
            '--group-id', aws_security_group_get_id(region => $args{region}, job_id => $args{job_id}),
            '--region', $args{region}));
}

=head2 aws_security_group_get_id

    my $sg_id = aws_security_group_get_id(region => 'europe', job_id => '12345');

Retrieve the security group ID associated with a specific OpenQA job
Returns the security group ID

=over

=item B<region> - AWS region where the security group is located

=item B<job_id> - OpenQA job identifier used to tag the security group

=back
=cut

sub aws_security_group_get_id(%args) {
    foreach (qw(region job_id)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    return script_output(join(' ',
            'aws ec2 describe-security-groups',
            "--filters 'Name=tag:OpenQAJobSg,Values=$args{job_id}'",
            '--region', $args{region},
            " --query 'SecurityGroups[0].GroupId' --output text"));
}

=head2 aws_security_group_authorize_ingress

    aws_security_group_authorize_ingress(
        sg_id => ,
        protocol => ,
        port =>,
        cidr =>,
        region => );

Add an ingress rule to a security group allowing traffic from a specific CIDR block

=over

=item B<sg_id> - ID of the security group to modify

=item B<protocol> - protocol for the rule (e.g., 'tcp', 'udp', 'icmp')

=item B<port> - port number or port range for the rule

=item B<cidr> - CIDR block allowed to access (e.g., '0.0.0.0/0' for all)

=item B<region> - AWS region where the security group is located

=back
=cut

sub aws_security_group_authorize_ingress(%args) {
    foreach (qw(sg_id protocol port cidr region)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }

    assert_script_run(join(' ',
            'aws ec2 authorize-security-group-ingress',
            '--group-id', $args{sg_id},
            '--protocol', $args{protocol},
            '--port', $args{port},
            '--cidr', $args{cidr},
            '--region', $args{region}));
}

=head2 aws_subnet_create

    my $subnet_id = aws_subnet_create(
        region => 'us-west-1',
        cidr => '10.0.1.0/24',
        vpc_id => 'vpc-12345',
        job_id => '67890'
    );

Create a subnet within a VPC with a specified CIDR block and tag it with the OpenQA job ID
Returns the subnet ID

=over

=item B<region> - AWS region where to create the subnet

=item B<cidr> - CIDR block for the subnet (e.g., '10.0.1.0/24')

=item B<vpc_id> - ID of the VPC where the subnet will be created

=item B<job_id> - OpenQA job identifier used to tag the security group

=back
=cut

sub aws_subnet_create(%args) {
    foreach (qw(region cidr vpc_id job_id)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }
    my @cmd = (
        'aws ec2 create-subnet',
        '--region', $args{region},
        '--cidr-block', $args{cidr},
        '--vpc-id', $args{vpc_id},
        '--query', "'Subnet.SubnetId'",
        '--output', 'text'
    );
    push(@cmd, '--availability-zone', $args{availability_zone}) if $args{availability_zone};
    my $subnet_id = script_output(join(' ', @cmd));
    die('Subnet creation failed: Subnet ID is empty') unless $subnet_id;
    assert_script_run(join(' ',
            'aws ec2 create-tags',
            '--resources', $subnet_id,
            '--tags', "Key=OpenQAJobSubnet,Value=$args{job_id}",
            '--region', $args{region}
    ));
    return $subnet_id;
}

=head2 aws_subnet_get_ids

    my @subnet_ids = aws_subnet_get_ids(
        region => 'us-west-1',
        job_id => '67890'
    );

Retrieve the list of subnet IDs associated with a specific OpenQA job
Returns the list of subnet IDs

=over

=item B<region> - AWS region where the subnets are located

=item B<job_id> - OpenQA job identifier used to tag the subnets

=back
=cut

sub aws_subnet_get_ids(%args) {
    foreach (qw(region job_id)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }
    my $output = script_output(join(' ',
            'aws ec2 describe-subnets',
            '--filters', "'Name=tag:OpenQAJobSubnet,Values=$args{job_id}'",
            '--region', $args{region},
            '--query', "'Subnets[*].SubnetId'",
            '--output', 'json'
    ));
    return @{decode_json($output)};
}

=head2 aws_subnet_delete

    my $ret = aws_subnet_delete(
        region => 'us-west-1',
        job_id => '67890'
    );

Delete the subnets associated with the job, do not assert but return the exit code of the command.

=over

=item B<region> - AWS region where the subnets are located

=item B<job_id> - OpenQA job identifier used to tag the subnets

=back
=cut

sub aws_subnet_delete(%args) {
    foreach (qw(region job_id)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }
    my @subnet_ids = aws_subnet_get_ids(region => $args{region}, job_id => $args{job_id});
    my $exit_code = 0;
    foreach my $subnet_id (@subnet_ids) {
        my $rc = script_run(join(' ',
                'aws ec2 delete-subnet',
                '--subnet-id', $subnet_id,
                '--region', $args{region}));
        $exit_code = $rc if ($rc != 0);
    }
    return $exit_code;
}

=head2 aws_internet_gateway_create

    my $igw_id = aws_internet_gateway_create
        region => 'us-west-1',
        job_id => '67890'
    );

Create an internet gateway and tag it with the OpenQA job ID
Returns the internet gateway ID

=over

=item B<region> - AWS region where to create the internet gateway

=item B<job_id> - OpenQA job identifier used to tag the security group

=back
=cut

sub aws_internet_gateway_create(%args) {
    foreach (qw(region job_id)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }
    my $igw_id = script_output(join(' ',
            'aws ec2 create-internet-gateway',
            '--region', $args{region},
            '--query', "'InternetGateway.InternetGatewayId'",
            '--output', 'text'
    ), 60);
    assert_script_run(join(' ',
            'aws ec2 create-tags',
            '--resources', $igw_id,
            '--tags', "Key=OpenQAJobIgw,Value=$args{job_id}",
            '--region', $args{region}
    ));
    return $igw_id;
}

=head2 aws_internet_gateway_get_id

    my $igw_id = aws_internet_gateway_get_id(
        region => 'us-west-1',
        job_id => '67890'
    );

Retrieve the internet gateway ID associated with a specific OpenQA job
Returns the internet gateway ID

=over

=item B<region> - AWS region where the internet gateway is located

=item B<job_id> - OpenQA job identifier used to tag the internet gateway

=back
=cut

sub aws_internet_gateway_get_id(%args) {
    foreach (qw(region job_id)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }
    return script_output(join(' ',
            'aws ec2 describe-internet-gateways',
            '--filters', "'Name=tag:OpenQAJobIgw,Values=$args{job_id}'",
            '--region', $args{region},
            '--query', "'InternetGateways[0].InternetGatewayId'",
            '--output', 'text'
    ));
}

=head2 aws_internet_gateway_attach

    aws_internet_gateway_attach(
        vpc_id => 'vpc-12345',
        igw_id => 'igw-abcde',
        region => 'us-west-1'
    );

Attach an internet gateway to a VPC

=over

=item B<vpc_id> - ID of the VPC to attach the gateway to

=item B<igw_id> - ID of the internet gateway to attach

=item B<region> - AWS region where the resources are located

=back
=cut

sub aws_internet_gateway_attach(%args) {
    foreach (qw(vpc_id igw_id region)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }
    assert_script_run(join(' ',
            'aws ec2 attach-internet-gateway',
            '--vpc-id', $args{vpc_id},
            '--internet-gateway-id', $args{igw_id},
            '--region', $args{region}
    ));
}

=head2 aws_internet_gateway_delete

    my $ret = aws_internet_gateway_delete(
        job_id => '6789',
        vpc_id => 'vpc-12345',
        region => 'us-west-1'
    );

Delete the internet gateway, do not assert but return the exit code of the command.

=over

=item B<region> - AWS region where the resources are located

=item B<vpc_id> - ID of the VPC to attach the gateway to

=item B<job_id> - OpenQA job identifier for tagging

=back
=cut

sub aws_internet_gateway_delete(%args) {
    foreach (qw(region vpc_id job_id)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }
    my $ret;
    my $igw_id = aws_internet_gateway_get_id(region => $args{region}, job_id => $args{job_id});
    $ret = script_run(join(' ',
            'aws ec2 detach-internet-gateway',
            '--vpc-id', $args{vpc_id},
            '--internet-gateway-id', $igw_id,
            '--region', $args{region}));
    return $ret if ($ret != 0);
    return script_run(join(' ',
            'aws ec2 delete-internet-gateway',
            '--internet-gateway-id', $igw_id,
            '--region', $args{region}));
}

=head2 aws_route_table_create

    my $route_table_id = aws_route_table_create(
        region => 'us-west-1',
        vpc_id => 'vpc-12345'
    );

Create a route table within a VPC
Returns the route table ID

=over

=item B<region> - AWS region where to create the route table

=item B<vpc_id> - ID of the VPC where the route table will be created

=back
=cut

sub aws_route_table_create(%args) {
    foreach (qw(region vpc_id)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }
    return script_output(join(' ',
            'aws ec2 create-route-table',
            '--vpc-id', $args{vpc_id},
            '--region', $args{region},
            '--query', "'RouteTable.RouteTableId'",
            '--output', 'text'),
        180);
}

=head2 aws_route_table_associate

    aws_route_table_associate(
        subnet_id => 'subnet-12345',
        route_table_id => 'rtb-abcde',
        region => 'us-west-1'
    );

Associate a route table with a subnet

=over

=item B<subnet_id> - ID of the subnet to associate

=item B<route_table_id> - ID of the route table to associate

=item B<region> - AWS region where the resources are located

=back
=cut

sub aws_route_table_associate(%args) {
    foreach (qw(subnet_id route_table_id region)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }
    assert_script_run(join(' ',
            'aws ec2 associate-route-table',
            '--subnet-id', $args{subnet_id},
            '--route-table-id', $args{route_table_id},
            '--region', $args{region},
            '--query', "'AssociationId'",
            '--output', 'text'));
}

=head2 aws_route_table_delete

    my $ret = aws_route_table_delete(
        vpc_id => 'subnet-12345',
        region => 'us-west-1'
    );

Delete the route table(s), do not assert but return the first non-zero exit code of the commands, or 0 on success.

=over

=item B<vpc_id> - ID of the VPC

=item B<region> - AWS region where the resources are located

=back
=cut

sub aws_route_table_delete(%args) {
    foreach (qw(vpc_id region)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }
    my $rtb_ids = script_output(join(' ',
            'aws ec2 describe-route-tables',
            "--filters Name=vpc-id,Values=$args{vpc_id}",
            "--query 'RouteTables[?Associations[0].Main!=\`true\`].RouteTableId'",
            '--output text',
            '--region', $args{region}));
    for my $id (split(/\s+/, $rtb_ids)) {
        my $ret = script_run(join(' ',
                'aws ec2 delete-route-table',
                '--route-table-id', $id,
                '--region', $args{region}));
        return $ret if $ret;
    }
    return 0;
}

=head2 aws_route_create

    aws_route_create(
        route_table_id => 'rtb-12345',
        destination_cidr_block => '0.0.0.0/0',
        igw_id => 'igw-abcde',
        region => 'us-west-1'
    );

Create a route in a route table pointing to an internet gateway

=over

=item B<route_table_id> - ID of the route table where to create the route

=item B<destination_cidr_block> - destination CIDR block for the route (e.g., '0.0.0.0/0' for default route)

=item B<igw_id> - ID of the internet gateway as the route target

=item B<region> - AWS region where the resources are located

=back
=cut

sub aws_route_create(%args) {
    foreach (qw(route_table_id destination_cidr_block igw_id region)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }
    assert_script_run(join(' ',
            'aws ec2 create-route',
            '--route-table-id', $args{route_table_id},
            '--destination-cidr-block', $args{destination_cidr_block},
            '--gateway-id', $args{igw_id},
            '--region', $args{region}
    ));
}

=head2 aws_vm_create

    my $instance_id = aws_vm_create(
        instance_type => 't2.micro',
        image_name    => 'sles-15-sp3',
        subnet_id     => 'subnet-12345',
        sg_id         => 'sg-abcde',
        ssh_key       => 'my-key',
        region        => 'us-west-1',
        job_id        => '67890'
    );

Launch an EC2 instance with specified configuration and tag it with the OpenQA job ID
Returns the instance ID

=over

=item B<instance_type> - EC2 instance type (e.g., 't2.micro', 'm5.large')

=item B<image_name> - Name to use for the instance

=item B<owner> - Image owner, used to serch the AMI

=item B<subnet_id> - ID of the subnet where to launch the instance

=item B<sg_id> - ID of the security group to assign to the instance

=item B<ssh_key> - name of the SSH key pair for instance access

=item B<region> - AWS region where to launch the instance

=item B<job_id> - OpenQA job identifier used to tag the internet gateway

=back
=cut

sub aws_vm_create(%args) {
    foreach (qw(instance_type image_name owner subnet_id sg_id ssh_key region job_id)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }

    my $image_id = script_output(join(' ',
            'aws ec2 describe-images',
            "--filters 'Name=name,Values=" . $args{image_name} . "-*'",
            "--owners '$args{owner}'",
            "--query 'Images[?Name != `ecs`]|[0].ImageId'",
            '--output=text'), 240);

    die("Image name:$args{image_name} Owner:$args{owner} --> Image ID:$image_id") if ($image_id eq 'None');
    return script_output(join(' ',
            'aws ec2 run-instances',
            '--image-id', $image_id,
            '--count', '1',
            '--subnet-id', $args{subnet_id},
            '--associate-public-ip-address',
            '--security-group-ids', $args{sg_id},
            '--instance-type', $args{instance_type},
            '--tag-specifications', "\"ResourceType=instance,Tags=[{Key=OpenQAJobVm,Value=\'$args{job_id}\'}]\"",
            '--query', "'Instances[0].InstanceId'",
            '--key-name', $args{ssh_key},
            '--output', 'text'), 240);
}

=head2 aws_vm_get_id

    my $instance_id = aws_vm_get_id(
        region => 'us-west-1',
        job_id => '67890'
    );

Retrieve the EC2 instance ID associated with a specific OpenQA job
Returns the instance ID

=over

=item B<region> - AWS region where the instance is located

=item B<job_id> - OpenQA job identifier used to tag the instance

=back
=cut

sub aws_vm_get_id(%args) {
    foreach (qw(region job_id)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }
    return script_output(join(' ',
            'aws ec2 describe-instances',
            '--filters', "'Name=tag:OpenQAJobVm,Values=$args{job_id}'",
            '--query', "'Reservations[*].Instances[*].InstanceId'",
            '--output', 'text',
            '--region', $args{region}));
}

=head2 aws_vm_wait_status_ok

    aws_vm_wait_status_ok(
        instance_id => 'i-12345'
    );

Wait for an EC2 instance to reach 'running' state with a timeout of 600 seconds

=over

=item B<instance_id> - ID of the instance to monitor

=back
=cut

sub aws_vm_wait_status_ok(%args) {
    croak("Argument < instance_id > missing") unless $args{instance_id};

    script_retry(join(' ',
            'aws ec2 describe-instances',
            '--instance-ids', $args{instance_id},
            '--query', "'Reservations[*].Instances[*].State.Name'",
            '--output', 'text',
            '|', 'grep', "'running'"
    ), 90, delay => 15, retry => 12);
}

=head2 aws_get_ip_address

    my $ip = aws_get_ip_address(
        instance_id => 'i-12345'
    );

Retrieve the public IP address of an EC2 instance
Returns the public IP address

=over

=item B<instance_id> - ID of the instance

=back
=cut

sub aws_get_ip_address(%args) {
    foreach (qw(instance_id)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }
    return script_output(join(' ',
            'aws ec2 describe-instances',
            '--instance-ids', $args{instance_id},
            '--query', "'Reservations[0].Instances[0].PublicIpAddress'",
            '--output', 'text'),
        90);
}

=head2 aws_vm_terminate

    my $ret = aws_vm_terminate(
        region => 'us-west-1',
        instance_id => 'i-12345'
    );

Terminate an EC2 instance and wait for it to be terminated, do not assert but return the exit code of the command.

=over

=item B<region> - AWS region where the instance is located

=item B<instance_id> - ID of the instance to terminate

=back
=cut

sub aws_vm_terminate(%args) {
    foreach (qw(region instance_id)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }

    my $ret;
    # Terminate instance and wait
    $ret = script_run(join(' ',
            'aws ec2 terminate-instances',
            '--instance-ids', $args{instance_id},
            '--region', $args{region}));
    return $ret if ($ret != 0);
    return script_run(join(' ',
            'aws ec2 wait instance-terminated',
            '--instance-ids', $args{instance_id},
            '--region', $args{region}), timeout => 300);
}

=head2 aws_ssh_key_pair_import

    aws_ssh_key_pair_import(
        ssh_key      => 'my-key',
        pub_key_path => '/path/to/key.pub'
    );

Import an SSH public key pair into AWS EC2 for instance authentication

=over

=item B<ssh_key> - name to assign to the imported key pair in AWS

=item B<pub_key_path> - filesystem path to the public key file

=back
=cut

sub aws_ssh_key_pair_import(%args) {
    foreach (qw(ssh_key pub_key_path)) {
        croak("Argument < $_ > missing") unless $args{$_};
    }
    assert_script_run(join(' ',
            'aws ec2 import-key-pair',
            '--key-name', $args{ssh_key},
            '--public-key-material', "fileb://$args{pub_key_path}"));
}

=head2 aws_tgw_vpc_attachment_get_id

    my $attach_id = aws_tgw_vpc_attachment_get_id(region => 'us-west-1', job_id => 'job-123');

Retrieve the TGW attachment ID associated with a specific OpenQA job.
Returns the TGW attachment ID as a string. Only the first element found is returned.

=cut

sub aws_tgw_vpc_attachment_get_id(%args) {
    foreach (qw(region job_id)) {
        croak("Argument < $_ > missing") unless $args{$_}; }

    my $name_tag = $args{job_id} . '-tga';
    return script_output(join(' ',
            'aws ec2 describe-transit-gateway-vpc-attachments',
            "--filters 'Name=tag:Name,Values=$name_tag'",
            '--region', $args{region},
            "--query 'TransitGatewayVpcAttachments[0].TransitGatewayAttachmentId' --output text"));
}

=head2 aws_filter_query

    my $res = aws_filter_query(cmd => 'describe-instances', filter => 'Name=instance-id,Values=i-123', query => 'Reservations[*].Instances[*].InstanceId');

Generic function to compose a aws cli command with filter and query.
Returns the script output.

=over

=item B<cmd> - AWS EC2 subcommand

=item B<filter> - Filter string

=item B<query> - JMESPath query string

=item B<output> - Output format (default: text)

=back
=cut

sub aws_filter_query(%args) {
    foreach (qw(cmd filter query)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $output_format = $args{output} // 'text';
    my @cmd = ('aws ec2', $args{cmd},
        '--filters', $args{filter},
        '--query', $args{query},
        '--output', $output_format);
    push(@cmd, '--region', $args{region}) if $args{region};
    return script_output(join(' ', @cmd));
}

=head2 aws_tgw_get_id

    my $tgw_id = aws_tgw_get_id(mirror_tag => 'my-project');

Return the Transit Gateway ID associated with a specific Project tag.

=over

=item B<mirror_tag> - Value of Project tag

=item B<region> - Region

=back
=cut

sub aws_tgw_get_id(%args) {
    foreach (qw(mirror_tag region)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    return aws_filter_query(
        cmd => 'describe-transit-gateways',
        filter => '"Name=tag:Project,Values=' . $args{mirror_tag} . '"',
        query => '"TransitGateways[].TransitGatewayId"',
        region => $args{region}
    );
}

=head2 aws_vpc_get_subnets

    my @subnets = aws_vpc_get_subnets(vpc_id => 'vpc-123', region => 'us-east-1');

Return a list of subnets for a VPC, one per Availability Zone.

=over

=item B<vpc_id> - VPC ID

=item B<region> - AWS region

=back
=cut

sub aws_vpc_get_subnets(%args) {
    croak 'Missing mandatory vpc_id argument' unless $args{vpc_id};

    my @cmd = ('aws ec2 describe-subnets',
        '--filters', "\"Name=vpc-id,Values=$args{vpc_id}\"",
        '--query "Subnets[].{AZ:AvailabilityZone,SI:SubnetId}"',
        '--output json');
    push(@cmd, '--region', $args{region}) if $args{region};

    my $describe_subnets = decode_json(script_output(join(' ', @cmd)));
    my %seen = ();
    my @uniq = ();
    foreach (@{$describe_subnets}) {
        push(@uniq, $_->{SI}) unless $seen{$_->{AZ}}++;
    }
    return @uniq;
}

=head2 aws_vpc_get_routing_tables

    my $rt_ids = aws_vpc_get_routing_tables(vpc_id => 'vpc-123', region => 'us-east-1');

Get routing table IDs for a VPC that have external connections (non-local).

=over

=item B<vpc_id> - VPC ID

=item B<region> - AWS region

=back
=cut

sub aws_vpc_get_routing_tables(%args) {
    foreach (qw(vpc_id region)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    return aws_filter_query(
        cmd => 'describe-route-tables',
        filter => "\"Name=vpc-id,Values=$args{vpc_id}\"",
        query => '"RouteTables[?Routes[?GatewayId!=\`local\`]].RouteTableId"',
        region => $args{region}
    );
}

=head2 aws_tgw_attachment_get

    my $res = aws_tgw_attachment_get(name => 'my-attachment');

Get a description of one or more transit-gateway-attachments.
Returns an array reference of hash references (list of dicts).
    return value = [ {State => 'pending'} ...]

=over

=item B<transit_gateway_attach_id> - Optional ID of the attachment

=item B<name> - Optional Name tag value

=back
=cut

sub aws_tgw_attachment_get(%args) {
    my $filter = '';
    if ($args{transit_gateway_attach_id}) {
        $filter = "--filter='Name=transit-gateway-attachment-id,Values=$args{transit_gateway_attach_id}'";
    }
    elsif ($args{name}) {
        $filter = "--filter='Name=tag:Name,Values=$args{name}'";
    }
    my @cmd = ('aws ec2 describe-transit-gateway-attachments',
        $filter,
        '--query "TransitGatewayAttachments[]"',
        '--output json');
    push(@cmd, '--region', $args{region}) if $args{region};
    return decode_json(script_output(join(' ', @cmd)));
}

=head2 aws_tgw_attachment_create

    aws_tgw_attachment_create(
        transit_gateway_id => 'tgw-123',
        vpc_id => 'vpc-456',
        subnet_id_list => ['subnet-1'],
        name => 'my-attach'
    );

Create a Transit Gateway VPC attachment and wait until it is available.
Returns true if the attachment becomes available within the timeout, false otherwise.

=over

=item B<transit_gateway_id> - ID of the target Transit gateway

=item B<vpc_id> - VPC ID to be attached

=item B<subnet_id_list> - List of subnet IDs to connect

=item B<name> - Prefix for the Tag Name of the attachment

=item B<timeout> - Timeout in seconds (default 300)

=back
=cut

sub aws_tgw_attachment_create(%args) {
    foreach (qw(transit_gateway_id vpc_id subnet_id_list name))
    { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{timeout} //= bmwqemu::scale_timeout(300);

    my $cmd = join(' ', 'aws ec2 create-transit-gateway-vpc-attachment',
        '--transit-gateway-id', $args{transit_gateway_id},
        '--vpc-id', $args{vpc_id},
        '--subnet-ids', join(' ', @{$args{subnet_id_list}}),
        '--tag-specifications',
        '"ResourceType=transit-gateway-attachment,Tags=[{Key=Name,Value=' . $args{name} . '-tga}]"',
        '--output json');
    my $describe_tgva = decode_json(script_output($cmd));
    return 0 unless $describe_tgva;

    my $res;
    my $state = 'none';
    my $duration;
    my $start_time = time();
    while ((($duration = time() - $start_time) < $args{timeout}) && ($state !~ m/available/)) {
        sleep 5;
        $res = aws_tgw_attachment_get(
            transit_gateway_attach_id => $describe_tgva->{TransitGatewayVpcAttachment}->{TransitGatewayAttachmentId});
        $state = $res->[0]->{State};
    }
    return $duration < $args{timeout};
}

=head2 aws_tgw_attachment_delete

    aws_tgw_attachment_delete(id => 'tgwa-123');

Delete a Transit Gateway VPC attachment and wait until it is deleted.
Returns true if the attachment is successfully deleted (or if wait is set to 0), false if it times out while waiting for the deleted state.

=over

=item B<id> - ID of the TGW attachment to be deleted

=item B<timeout> - Timeout in seconds (default 300)

=item B<wait> - whether to wait to verify deleted status or not (default 1)

=back
=cut

sub aws_tgw_attachment_delete(%args) {
    croak 'Must provide transit gateway id' unless $args{id};
    $args{timeout} //= bmwqemu::scale_timeout(300);
    $args{wait} //= 1;

    my @cmd = ('aws ec2 delete-transit-gateway-vpc-attachment', '--transit-gateway-attachment-id', $args{id});
    push(@cmd, '--region', $args{region}) if $args{region};
    script_run(join(' ', @cmd));

    return 1 unless $args{wait};

    my $state = 'none';
    my $duration;
    my $start_time = time();
    my $res;
    while ((($duration = time() - $start_time) < $args{timeout})
        && ($state !~ m/deleted/))
    {
        sleep 5;
        $res = aws_tgw_attachment_get(transit_gateway_attach_id => $args{id}, region => $args{region});

        last unless @$res;
        $state = $res->[0]{State};
    }
    return $duration < $args{timeout};
}

=head2 aws_route_create_tgw

    aws_route_create_tgw(rtable_id => 'rtb-1', target_ip_net => '10.0.0.0/8', trans_gw_id => 'tgw-1');

Add a route to a Transit Gateway in a routing table.

=over

=item B<rtable_id> - Routing table ID

=item B<target_ip_net> - Target CIDR block

=item B<trans_gw_id> - Transit Gateway ID

=back
=cut

sub aws_route_create_tgw(%args) {
    foreach (qw(rtable_id target_ip_net trans_gw_id)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $cmd = join(' ',
        'aws ec2 create-route',
        '--route-table-id', $args{rtable_id},
        '--destination-cidr-block', $args{target_ip_net},
        '--transit-gateway-id', $args{trans_gw_id},
        '--output text');
    script_run($cmd);
}

1;
