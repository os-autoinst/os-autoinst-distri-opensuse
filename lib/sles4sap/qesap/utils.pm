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
use Time::Piece;

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

sub _sanitize_gcp_label {
    my ($value) = @_;
    # GCP label values must be lowercase
    $value =~ tr/A-Z/a-z/;
    # GCP label values allow only [a-z0-9_-]
    $value =~ s/[^a-z0-9_-]//g;
    # GCP label values are at most 63 characters
    return substr($value, 0, 63);
}

=head3 qesap_get_public_cloud_tags

    my %tags = qesap_get_public_cloud_tags();

Calculate tags to match CloudCustodian needs.
Return a dictionary.

B<openqa_created_date> is the creation time used by the CloudCustodian
cleanup policies (C<value_type: age>, C<key: tag:openqa_created_date>).
The value is in ISO 8601 basic format with an explicit UTC designator,
e.g. C<20261110T030612Z>:

=over

=item * CloudCustodian parses it with C<dateutil>. A value without a timezone
is read as the local time of the CloudCustodian host. A value it cannot
parse is never matched, so the resource is never cleaned up.

=item * The value uses only characters valid in tag values.

=item * The basic format has no C<-> date separators, so YAML 1.1 parsers
keep it as a string. The extended format (C<2026-11-10T03:06:12Z>) is
converted to a date and written back with a space, which the tag
validation of the deployment rejects.

=back

=cut

sub qesap_get_public_cloud_tags {
    my $openqa_var_server = get_var('OPENQA_URL') // get_required_var('OPENQA_HOSTNAME');
    # Remove the http://, https://, and/or the slash at the end
    $openqa_var_server =~ s@^https?://|/$@@g;
    $openqa_var_server = _sanitize_gcp_label($openqa_var_server);

    my $openqa_var_name = get_var('NAME', '');
    # Remove the @... suffix (e.g. @64bit)
    $openqa_var_name =~ s/@.*$//;
    $openqa_var_name = _sanitize_gcp_label($openqa_var_name);

    my %tags = (
        openqa_var_job_id => get_current_job_id(),
        openqa_var_name => $openqa_var_name,
        openqa_var_server => $openqa_var_server,
        # Read by CloudCustodian 'value_type: age' filters. The trailing 'Z'
        # is required: a value without a timezone is read as the local time
        # of the CloudCustodian host. See POD for the format details.
        openqa_created_date => gmtime->strftime('%Y%m%dT%H%M%SZ'),
    );
    return %tags;
}

1;
