# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Internal utility functions only used by qesapdeployment
# Maintainer: QE-SAP <qe-sap@suse.de>

## no critic (RequireFilenameMatchesPackage);

=encoding utf8

=head1 NAME

    qesap-utils lib

=head1 COPYRIGHT

    Copyright 2025 SUSE LLC
    SPDX-License-Identifier: FSFAP

=head1 AUTHORS

    QE SAP <qe-sap@suse.de>

=cut

package sles4sap::qesap::utils;

use strict;
use warnings;
use Carp qw(croak);
use Mojo::JSON qw(decode_json);
use Exporter 'import';
use testapi;
use mmapi qw( get_current_job_id );

our @EXPORT = qw(
  qesap_is_job_finished
  qesap_get_public_cloud_tags
);

=head1 DESCRIPTION

    Package with util qesap-deployment functions

=head2 Methods

=head3 qesap_is_job_finished

    Get whether a specified job is still running or not. 
    In cases of ambiguous responses, they are considered to be in `running` state.

=over

=item B<JOB_ID> - id of job to check

=back
=cut

sub qesap_is_job_finished {
    my (%args) = @_;
    croak 'Missing mandatory job_id argument' unless $args{job_id};

    my $url = get_required_var('OPENQA_HOSTNAME')
      . "/api/v1/experimental/jobs/$args{job_id}/status";

    my $json_data = script_output("curl -s '$url'", quiet => 1);

    my $job_data = eval { decode_json($json_data) };
    if ($@) {
        record_info(
            "OPENQA QUERY FAILED",
            "Failed to decode JSON data for job $args{job_id}: $@"
        );
        return 0;    # assume job is still running if we cannot get the data
    }

    my $job_state = $job_data->{state} // 'running';    # assume running if missing
    return ($job_state ne 'running');
}

=head3 qesap_get_public_cloud_tags

    my $tags = qesap_get_public_cloud_tags();

Retrieve tags from the `PUBLIC_CLOUD_TAGS` openQA setting, map key=value pairs,
override `openqa_var_job_id` with get_current_job_id(), and return a formatted,
space-separated string suitable for the `--tags` argument of the az cli.

=cut

sub qesap_get_public_cloud_tags {
    my $tags = '';
    if (my $value = get_var('PUBLIC_CLOUD_TAGS')) {
        my %tags_hash = map { if (/([^=]+)=([^=]+)/) { $1 => "$2" } else { $_ => 1 } } split(/,/, $value);
        $tags_hash{openqa_var_job_id} = get_current_job_id() if exists $tags_hash{openqa_var_job_id};
        $tags = join(' ', map { "$_=$tags_hash{$_}" } sort keys %tags_hash);
    }
    return $tags;
}

1;
