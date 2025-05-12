# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Functions relate to AWS to use qe-sap-deployment project
# Maintainer: QE-SAP <qe-sap@suse.de>

## no critic (RequireFilenameMatchesPackage);

=encoding utf8

=head1 NAME

    AWS related functions for the qe-sap-deployment test lib

=head1 COPYRIGHT

    Copyright 2025 SUSE LLC
    SPDX-License-Identifier: FSFAP

=head1 AUTHORS

    QE SAP <qe-sap@suse.de>

=cut

package sles4sap::qesap::qesap_aws;

use strict;
use warnings;
use Carp qw(croak);
use Mojo::JSON qw(decode_json);
use Exporter 'import';
use testapi;

our @EXPORT = qw(
  qesap_aws_get_vpc_id
  qesap_aws_delete_transit_gateway_vpc_attachment
  qesap_aws_get_transit_gateway_vpc_attachment
  qesap_aws_add_route_to_tgw
  qesap_aws_get_mirror_tg
  qesap_aws_get_vpc_workspace
  qesap_aws_get_routing
  qesap_aws_vnet_peering
  qesap_aws_create_credentials
  qesap_aws_create_config
);

=head1 DESCRIPTION

    Package with AWS related methods for qe-sap-deployment

=head2 Methods

=head3 qesap_aws_get_region_subnets

Return a list of subnets. Return a single subnet for each region.

=over

=item B<VPC_ID> - VPC ID of resource to filter list of subnets

=back
=cut

sub qesap_aws_get_region_subnets {
    my (%args) = @_;
    croak 'Missing mandatory vpc_id argument' unless $args{vpc_id};

    my $cmd = join(' ', 'aws ec2 describe-subnets',
        '--filters', "\"Name=vpc-id,Values=$args{vpc_id}\"",
        '--query "Subnets[].{AZ:AvailabilityZone,SI:SubnetId}"',
        '--output json');

    my $describe_vpcs = decode_json(script_output($cmd));
    my %seen = ();
    my @uniq = ();
    foreach (@{$describe_vpcs}) {
        push(@uniq, $_->{SI}) unless $seen{$_->{AZ}}++;
    }
    return @uniq;
}

=head3 qesap_aws_create_credentials

    Creates a AWS credentials file as required by QE-SAP Terraform deployment code.

=over

=item B<KEY> - value for the aws_access_key_id

=item B<SECRET> - value for the aws_secret_access_key

=item B<CONF_TRGT> - qesap_conf_trgt value in the output of qesap_get_file_paths

=back
=cut

sub qesap_aws_create_credentials {
    my (%args) = @_;
    foreach (qw(key secret conf_trgt)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $credfile = script_output q|awk -F ' ' '/aws_credentials/ {print $2}' | . $args{conf_trgt};
    save_tmp_file('credentials', "[default]\naws_access_key_id = $args{key}\naws_secret_access_key = $args{secret}\n");
    assert_script_run 'mkdir -p ~/.aws';
    assert_script_run 'curl ' . autoinst_url . "/files/credentials -o $credfile";
    assert_script_run "cp $credfile ~/.aws/credentials";
}

=head3 qesap_aws_create_config

    Creates a AWS configuration file in ~/.aws/config
    as required by the QE-SAP Terraform & Ansible deployment code.
    Content is mostly (only) about region.

=over

=item B<REGION> - cloud region as usually provided by PUBLIC_CLOUD_REGION

=back
=cut

sub qesap_aws_create_config {
    my (%args) = @_;
    croak "Missing mandatory region argument" unless $args{region};

    save_tmp_file('config', "[default]\nregion = $args{region}\n");
    assert_script_run 'mkdir -p ~/.aws';
    assert_script_run 'curl ' . autoinst_url . "/files/config -o ~/.aws/config";
}

=head3 qesap_aws_get_vpc_id

    Get the vpc_id of a given instance in the cluster.
    This function looks for the cluster using the aws describe-instances
    and filtering by terraform deployment_name value, that qe-sap-deployment
    is kind to use as tag for each resource.

=cut

=over

=item B<RESOURCE_GROUP> - value of the workspace tag configured in qe-sap-deployment, usually it is the deployment name

=back
=cut

sub qesap_aws_get_vpc_id {
    my (%args) = @_;
    croak 'Missing mandatory resource_group argument' unless $args{resource_group};

    # tag names has to be aligned to
    # https://github.com/SUSE/qe-sap-deployment/blob/main/terraform/aws/infrastructure.tf
    my $cmd = join(' ', 'aws ec2 describe-instances',
        '--region', get_required_var('PUBLIC_CLOUD_REGION'),
        '--filters',
        '"Name=tag-key,Values=workspace"',
        "\"Name=tag-value,Values=$args{resource_group}\"",
        '--query',
        # the two 0 index result in select only the vpc of vmhana01
        # that is always equal to the one used by vmhana02
        "'Reservations[0].Instances[0].VpcId'",
        '--output text');
    return script_output($cmd);
}

=head3 qesap_aws_get_transit_gateway_vpc_attachment
    Ged a description of one or more transit-gateway-attachments
    Function support optional arguments that are translated to filters:
     - transit_gateway_attach_id
     - name

    Example:
      qesap_aws_get_transit_gateway_vpc_attachment(name => 'SOMETHING')

      Result internally in aws cli to be called like

      aws ec2 describe-transit-gateway-attachments --filter='Name=tag:Name,Values=SOMETHING

    Only one filter mode is supported at any time.

    Returns a HASH reference to the decoded JSON returned by the AWS command or undef on failure.
=cut

sub qesap_aws_get_transit_gateway_vpc_attachment {
    my (%args) = @_;
    my $filter = '';
    if ($args{transit_gateway_attach_id}) {
        $filter = "--filter='Name=transit-gateway-attachment-id,Values=$args{transit_gateway_attach_id}'";
    }
    elsif ($args{name}) {
        $filter = "--filter='Name=tag:Name,Values=$args{name}'";
    }
    my $cmd = join(' ', 'aws ec2 describe-transit-gateway-attachments',
        $filter,
        '--query "TransitGatewayAttachments[]"');
    return decode_json(script_output($cmd));
}

=head3 qesap_aws_create_transit_gateway_vpc_attachment

    Call create-transit-gateway-vpc-attachment and
    wait until Transit Gateway Attachment is available.

    Return 1 (true) if properly managed to create the transit-gateway-vpc-attachment
    Return 0 (false) if create-transit-gateway-vpc-attachment fails or
                  the gateway does not become active before the timeout

=over

=item B<TRANSIT_GATEWAY_ID> - ID of the target Transit gateway (IBS Mirror)

=item B<VPC_ID> - VPC ID of resource to be attached (SUT HANA cluster)

=item B<SUBNET_ID_LIST> - List of subnet to connect (SUT HANA cluster)

=item B<NAME> - Prefix for the Tag Name of transit-gateway-vpc-attachment

=item B<TIMEOUT> - default is 5 mins

=back
=cut

sub qesap_aws_create_transit_gateway_vpc_attachment {
    my (%args) = @_;
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

    my $transit_gateway_attachment_id = $describe_tgva->{TransitGatewayVpcAttachment}->{TransitGatewayAttachmentId};
    my $res;
    my $state = 'none';
    my $duration;
    my $start_time = time();
    while ((($duration = time() - $start_time) < $args{timeout}) && ($state !~ m/available/)) {
        sleep 5;
        $res = qesap_aws_get_transit_gateway_vpc_attachment(
            transit_gateway_attach_id => $transit_gateway_attachment_id);
        $state = $res->[0]->{State};
    }
    return $duration < $args{timeout};
}

=head3 qesap_aws_delete_transit_gateway_vpc_attachment

    Call delete-transit-gateway-vpc-attachment and
    wait until Transit Gateway Attachment is deleted.

    Return 1 (true) if properly managed to delete the transit-gateway-vpc-attachment
    Return 0 (false) if delete-transit-gateway-vpc-attachment fails or
         the gateway does not become inactive before the timeout

=over

=item B<NAME> - Prefix for the Tag Name of transit-gateway-vpc-attachment

=item B<TIMEOUT> - default is 5 mins

=back
=cut

sub qesap_aws_delete_transit_gateway_vpc_attachment {
    my (%args) = @_;
    croak 'Missing mandatory name argument' unless $args{name};
    $args{timeout} //= bmwqemu::scale_timeout(300);

    my $res = qesap_aws_get_transit_gateway_vpc_attachment(
        name => $args{name});
    # Here [0] suppose that only one of them match 'name'
    my $transit_gateway_attachment_id = $res->[0]->{TransitGatewayAttachmentId};
    return 0 unless $transit_gateway_attachment_id;

    my $cmd = join(' ', 'aws ec2 delete-transit-gateway-vpc-attachment',
        '--transit-gateway-attachment-id', $transit_gateway_attachment_id);
    script_run($cmd);

    my $state = 'none';
    my $duration;
    my $start_time = time();
    while ((($duration = time() - $start_time) < $args{timeout}) && ($state !~ m/deleted/)) {
        sleep 5;
        $res = qesap_aws_get_transit_gateway_vpc_attachment(
            transit_gateway_attach_id => $transit_gateway_attachment_id);
        $state = $res->[0]->{State};
    }
    return $duration < $args{timeout};
}

=head3 qesap_aws_add_route_to_tgw
    Adding the route to the transit gateway to the routing table in refhost VPC

=over

=item B<RTABLE_ID> - Routing table ID

=item B<TARGET_IP_NET> - Target IP network to be added to the Routing table eg. 192.168.11.0/16

=item B<TRANSIT_GATEWAY_ID> - ID of the target Transit gateway (IBS Mirror)

=back
=cut

sub qesap_aws_add_route_to_tgw {
    my (%args) = @_;
    foreach (qw(rtable_id target_ip_net trans_gw_id)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $cmd = join(' ',
        'aws ec2 create-route',
        '--route-table-id', $args{rtable_id},
        '--destination-cidr-block', $args{target_ip_net},
        '--transit-gateway-id', $args{trans_gw_id},
        '--output text');
    script_run($cmd);
}

=head3 qesap_aws_filter_query

    Generic function to compose a aws cli command with:
      - `aws ec2` something
      - use both `filter` and `query`
      - has text output

=cut

sub qesap_aws_filter_query {
    my (%args) = @_;
    foreach (qw(cmd filter query)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $cmd = join(' ', 'aws ec2', $args{cmd},
        '--filters', $args{filter},
        '--query', $args{query},
        '--output text');
    return script_output($cmd);
}

=head3 qesap_aws_get_mirror_tg

    Return the Transient Gateway ID of the IBS Mirror

=over

=item B<MIRROR_TAG> - Value of Project tag applied to the IBS Mirror

=back
=cut

sub qesap_aws_get_mirror_tg {
    my (%args) = @_;
    croak "Missing mandatory $_ argument" unless $args{mirror_tag};
    return qesap_aws_filter_query(
        cmd => 'describe-transit-gateways',
        filter => '"Name=tag-key,Values=Project" "Name=tag-value,Values=' . $args{mirror_tag} . '"',
        query => '"TransitGateways[].TransitGatewayId"'
    );
}

=head3 qesap_aws_get_vpc_workspace

    Get the VPC tag workspace defined in
    https://github.com/SUSE/qe-sap-deployment/blob/main/terraform/aws/infrastructure.tf

=over

=item B<VPC_ID> - VPC ID of resource to be attached (SUT HANA cluster)

=back
=cut

sub qesap_aws_get_vpc_workspace {
    my (%args) = @_;
    croak 'Missing mandatory vpc_id argument' unless $args{vpc_id};

    return qesap_aws_filter_query(
        cmd => 'describe-vpcs',
        filter => "\"Name=vpc-id,Values=$args{vpc_id}\"",
        query => '"Vpcs[*].Tags[?Key==\`workspace\`].Value"'
    );
}

=head3 qesap_aws_get_routing

    Get the Routing table: searching Routing Table with external connection
    and get the RouteTableId

=over

=item B<VPC_ID> - VPC ID of resource to be attached (SUT HANA cluster)

=back
=cut

sub qesap_aws_get_routing {
    my (%args) = @_;
    croak 'Missing mandatory vpc_id argument' unless $args{vpc_id};

    return qesap_aws_filter_query(
        cmd => 'describe-route-tables',
        filter => "\"Name=vpc-id,Values=$args{vpc_id}\"",
        query => '"RouteTables[?Routes[?GatewayId!=\`local\`]].RouteTableId"'
    );
}

=head3 qesap_aws_vnet_peering

    Create a pair of network peering between
    the two provided deployments.

    Return 1 (true) if the overall peering procedure completes successfully

=over

=item B<TARGET_IP> - Target IP network to be added to the Routing table eg. 192.168.11.0/16

=item B<VPC_ID> - VPC ID of resource to be attached (SUT HANA cluster)

=item B<MIRROR_TAG> - Value of Project tag applied to the IBS Mirror

=back
=cut

sub qesap_aws_vnet_peering {
    my (%args) = @_;
    foreach (qw(target_ip vpc_id mirror_tag)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $trans_gw_id = qesap_aws_get_mirror_tg(mirror_tag => $args{mirror_tag});
    unless ($trans_gw_id) {
        record_info('AWS PEERING', 'Empty trans_gw_id');
        return 0;
    }

    # For qe-sap-deployment this one match or contain the Terraform deloyment_name
    my $vpc_tag_name = qesap_aws_get_vpc_workspace(vpc_id => $args{vpc_id});
    unless ($vpc_tag_name) {
        record_info('AWS PEERING', 'Empty vpc_tag_name');
        return 0;
    }

    my @vpc_subnets_list = qesap_aws_get_region_subnets(vpc_id => $args{vpc_id});
    unless (@vpc_subnets_list) {
        record_info('AWS PEERING', 'Empty vpc_subnets_list');
        return 0;
    }

    my $rtable_id = qesap_aws_get_routing(vpc_id => $args{vpc_id});
    unless ($rtable_id) {
        record_info('AWS PEERING', 'Empty rtable_id');
        return 0;
    }

    # Setting up the peering
    # Attaching the VPC to the Transit Gateway
    my $attach = qesap_aws_create_transit_gateway_vpc_attachment(
        transit_gateway_id => $trans_gw_id,
        vpc_id => $args{vpc_id},
        subnet_id_list => \@vpc_subnets_list,
        name => $vpc_tag_name);
    unless ($attach) {
        record_info('AWS PEERING', 'VPC attach failure');
        return 0;
    }

    qesap_aws_add_route_to_tgw(
        rtable_id => $rtable_id,
        target_ip_net => $args{target_ip},
        trans_gw_id => $trans_gw_id);

    record_info('AWS PEERING SUCCESS');
    return 1;
}

1;
