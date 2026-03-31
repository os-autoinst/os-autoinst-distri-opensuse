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

package sles4sap::qesap::aws;

use strict;
use warnings;
use Carp qw(croak);
use Mojo::JSON qw(decode_json);
use Exporter 'import';
use testapi;

our @EXPORT = qw(
  qesap_aws_get_vpc_id
  qesap_aws_get_tgw_attachments
  qesap_aws_delete_transit_gateway_vpc_attachment
  qesap_aws_create_credentials
  qesap_aws_create_config
);

=head1 DESCRIPTION

    Package with AWS related methods for qe-sap-deployment

=head2 Methods

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

=head3 qesap_aws_delete_transit_gateway_vpc_attachment

    Call delete-transit-gateway-vpc-attachment and
    wait until Transit Gateway Attachment is deleted.

    Return 1 (true) if properly managed to delete the tgw-attachment OR 'wait' is 0
    Return 0 (false) if wait=1 AND delete-transit-gateway-vpc-attachment fails or timeout is reached

=over

=item B<ID> - id of the TGW attachment to be deleted

=item B<TIMEOUT> - default is 5 mins

=item B<WAIT> - whether to wait to verify deleted status or not

=back
=cut

sub qesap_aws_delete_transit_gateway_vpc_attachment {
    my (%args) = @_;
    croak 'Must provide transit gateway id' unless $args{id};
    $args{timeout} //= bmwqemu::scale_timeout(300);
    $args{wait} = $args{wait} // 1;

    my $cmd = join(' ', 'aws ec2 delete-transit-gateway-vpc-attachment', '--transit-gateway-attachment-id', $args{id});
    script_run($cmd);

    return 1 unless $args{wait};

    my $state = 'none';
    my $duration;
    my $start_time = time();
    my $res;
    while ((($duration = time() - $start_time) < $args{timeout})
        && ($state !~ m/deleted/))
    {
        sleep 5;
        $res = qesap_aws_get_transit_gateway_vpc_attachment(transit_gateway_attach_id => $args{id});

        last unless @$res;
        $state = $res->[0]{State};
    }
    return $duration < $args{timeout};
}

sub qesap_aws_get_tgw_attachments {
    my (%args) = @_;
    return [] unless $args{mirror_tag};

    my ($tgw_id) = qesap_aws_get_mirror_tg(mirror_tag => $args{mirror_tag});
    return [] unless $tgw_id;

    my @filters = (
        "Name=transit-gateway-id,Values=$tgw_id",
        "Name=tag:Name,Values='*-tgw-attach'",
        "Name=state,Values=available",
    );

    my $query = q{'TransitGatewayAttachments[].{Id:TransitGatewayAttachmentId,Name:Tags[?Key==`Name`]|[0].Value}'};

    my $atts_json = qesap_aws_filter_query(
        cmd => 'describe-transit-gateway-attachments',
        filter => join(' ', @filters),
        query => $query,
        output => 'json',
    );

    my $attachments = decode_json($atts_json);
    return $attachments;
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

    my $output_format = $args{output} // 'text';
    my $cmd = join(' ', 'aws ec2', $args{cmd},
        '--filters', $args{filter},
        '--query', $args{query},
        '--output', $output_format);
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

1;
