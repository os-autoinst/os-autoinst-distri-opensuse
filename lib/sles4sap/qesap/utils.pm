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

our @EXPORT = qw(
  qesap_is_job_finished
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

1;
