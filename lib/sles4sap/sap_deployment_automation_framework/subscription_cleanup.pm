# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
#
# Library used for cleaning up orphaned SDAF resources

package sles4sap::sap_deployment_automation_framework::subscription_cleanup;
use strict;
use warnings;
use testapi;
use Mojo::Base -signatures;
use Exporter qw(import);
use Time::Piece;
use Carp qw(croak);
use Mojo::JSON qw(encode_json);
use mmapi qw(get_parents get_job_autoinst_vars get_children get_job_info get_current_job_id);
use utils qw(write_sut_file);
use sles4sap::sap_deployment_automation_framework::deployment_connector qw(no_cleanup_tag);
use sles4sap::azure_cli;
use sles4sap::sap_deployment_automation_framework::deployment_connector qw(no_cleanup_tag);
use sles4sap::sap_deployment_automation_framework::naming_conventions
  qw(generate_deployer_name);

our @EXPORT = qw(
  get_orphaned_resource_groups
  destroy_orphaned_groups
  export_cleanup_report
  destroy_orphaned_resources
);

=head2 new

    my $cleanup_state = sles4sap::sap_deployment_automation_framework::subscription_cleanup->new();

Class is used to hold data structure containing all information regarding orphaned resources cleanup.

Structure:

=over

=item * B<openqa>: openQA job data: B<job_id>, B<instance>, B<start_time>, B<end_time>,
B<retention_sec>, B<test_result>.
B<retention_sec> is the retention period in seconds used to mark resources as orphaned.
Value of 'SDAF_CLEANUP_RETENTION_SEC' openQA setting (Default 12H).

=item * B<summary>: Resource group counters: B<found>, B<deleted>, B<failed>, B<skipped>.
Updated by C<get_orphaned_resource_groups()> and C<destroy_orphaned_groups()>.

=item * B<results>: Detailed results per resource type.

=back

=cut

sub new ($class) {
    # `state` initializes variables only once and keeps values across all class instances
    my $job_id = get_current_job_id();

    state $self = {
        openqa => {
            job_id => $job_id,
            instance => get_required_var('OPENQA_HOSTNAME'),
            start_time => get_job_info($job_id)->{t_started},
            retention_sec => get_var('SDAF_CLEANUP_RETENTION_SEC', 43200),
        },
        summary => {
            found => 0,
            deleted => 0,
            failed => 0,
            skipped => 0
        },
        results => {
            sap_systems => [],
            workload_zones => [],
            secrets => [],
            tfstate_files => [],
            deployer_vms => [],
            ibsm_peerings => []
        }
    };
    return bless $self, $class;
}

=head2 time_test

    time_test($input_time, $retention_sec);

Checks B<$input_time> against B<$retention_sec>.
Returns 'true' if time is older/greater that retention period, otherwise 0.

=over

=item * B<input_time>: Time to check against retention period

=item * B<retention_sec>: Retention period in seconds

=back

=cut

sub time_test ($input_time, $retention_sec) {
    croak 'Missing mandatory argument: $input_time' unless $input_time;
    croak 'Missing mandatory argument: $retention_sec' unless defined($retention_sec);
    my $retention_age = $retention_sec;
    # Couple of notes to time formats:
    # - for format explanation check 'man strftime' - az cli returns date in ISO 8601 format
    # - Time::Piece does not recognize microseconds, they need to be neutered using regex
    $input_time =~ s/\.\d+(?=\+\d\d)//;

    # - Time::Piece does not recognize az cli timezone format `+02:00`, only `+0200`
    #   - therefore we have to do some colonoscopy and remove `:` from az cli output
    $input_time =~ s/(?<=\+\d\d):(?=\d\d$)//;
    my $time = Time::Piece->strptime($input_time, '%Y-%m-%dT%H:%M:%S%z')->epoch();
    my $resource_orphaned = $time < time() - $retention_age ? 1 : 0;
    diag("\n[CLEANUP]Retention test:
        Resource age: $time
        Retention age: $retention_age
        Resource orphaned: $resource_orphaned"
    );
    return $resource_orphaned;
}

=head2 _kql_query

    my @kql = _kql_query(
        search_target => 'resourcecontainers',
        name_regex => '^SDAF-OpenQA-sap_system');

Returns an ARRAY of KQL statements for C<az_graph_query()> which help finding
resources matching following cleanup criteria:

=over

=item * Name matches B<name_regex> (case-sensitive).

=item * Tag C<no_cleanup_tag()> is not defined.

=item * Tags B<deployment_id> and B<openqa_created_date> are defined and not empty.

=back

Returned fields: B<name>, B<deployment_id>, B<openqa_created_date>.

=over

=item B<search_target> Azure Resource Graph table to search. Mandatory.

=item B<name_regex> RE2 regular expression for the resource name. Mandatory.

=back
=cut

sub _kql_query (%args) {
    croak 'Missing mandatory argument: <search_target>' unless $args{search_target};
    croak 'Missing mandatory argument: <name_regex>' unless $args{name_regex};
    my $kql_return_structure = join(', ',
        'id',    # Required for deleting list of resources
        'name',
        'deployment_id=tostring(tags.deployment_id)',
        'openqa_created_date=tostring(tags.openqa_created_date)'
    );
    my @kql_body = (
        $args{search_target},
        # '@' starts a KQL verbatim string. It is not a Perl array.
        "where name matches regex \@'$args{name_regex}'",
        "where not(bag_keys(tags) has '" . no_cleanup_tag() . "')",
        "where isnotempty(tags.deployment_id) and isnotempty(tags.openqa_created_date)",
        "project $kql_return_structure"
    );

    return @kql_body;
}

=head2 get_orphaned_resource_groups

    my $cleanup_result = sles4sap::sap_deployment_automation_framework::subscription_cleanup->new();
    $cleanup_result->get_orphaned_resource_groups();

Queries for all orphaned SDAF resource groups  not meeting retention criteria
and updates main class data. A workload zone is added only if a 'sap_system'
resource group with the same B<deployment_id> is already in the deletion list
C<< $self->{results}{sap_systems} >>. Or does not exist at all.

=cut

sub get_orphaned_resource_groups ($self) {
    my @sap_kql = _kql_query(
        search_target => 'resourcecontainers',
        name_regex => '^SDAF-OpenQA-sap_system-\d+$');
    my @workload_kql = _kql_query(
        search_target => 'resourcecontainers',
        name_regex => '^SDAF-OpenQA-workload_zone-\d+$');
    my $sap_groups = az_graph_query(statements => \@sap_kql, query => 'data', timeout => '360')->{output};
    my $workload_groups = az_graph_query(statements => \@workload_kql, query => 'data', timeout => '360')->{output};
    # Add 'result' key to the structure
    $_->{result} = undef for @{$sap_groups};
    $_->{result} = undef for @{$workload_groups};

    my $retention_sec = $self->{openqa}{retention_sec};

    # Mark all 'sap_systems' RG for deletion
    $self->{results}{sap_systems} = [map { time_test($_->{openqa_created_date}, $retention_sec) ? $_ : () } @{$sap_groups}];

    for my $group (@{$workload_groups}) {
        my $deployment_id = $group->{deployment_id};
        next unless time_test($group->{openqa_created_date}, $retention_sec);
        # Add workload zone if its 'sap_systems' RG is marked for deletion or does not exist at all
        next unless (grep { $_->{deployment_id} eq $deployment_id } @{$self->{results}{sap_systems}})
          or not(grep { $_->{deployment_id} eq $deployment_id } @{$sap_groups});
        push @{$self->{results}{workload_zones}}, $group;
    }
}

=head2 get_orphaned_resources

    my $cleanup_result = sles4sap::sap_deployment_automation_framework::subscription_cleanup->new();
    $cleanup_result->get_orphaned_resources();

Queries for all orphaned SDAF deployer VM resources not meeting retention criteria.


=cut

sub get_orphaned_resources ($self) {
    (my $name_query = generate_deployer_name()) =~ s/^\d+-//;
    my @kql = _kql_query(search_target => 'Resources', name_regex => "^\\d+-$name_query");
    my $resources = az_graph_query(statements => \@kql, query => 'data', timeout => '360')->{output};
    # Add 'result' key to the structure
    $_->{result} = undef for @{$resources};
    my $retention_sec = $self->{openqa}{retention_sec};

    # Mark all found resources for deletion
    $self->{results}{deployer_vms} = [map { time_test($_->{openqa_created_date}, $retention_sec) ? $_ : () } @{$resources}];
}

=head2 destroy_orphaned_groups

    my $cleanup_result = sles4sap::sap_deployment_automation_framework::subscription_cleanup->new();
    $cleanup_result->destroy_orphaned_groups();

Destroys all 'sap_systems' and 'workload_zone' resource groups which were marked as orphaned
by `get_orphaned_resource_groups()`

=cut

sub destroy_orphaned_groups ($self) {
    my @sap_systems = @{$self->{results}{sap_systems}};
    my @workload_zones = @{$self->{results}{workload_zones}};

    for my $group (@sap_systems, @workload_zones) {
        # Do not destroy group which have already been processed
        # Main intention is avoid destroying workload zone marked as 'skipped'
        # after SAP systems group failure
        next if $group->{result};
        my $rc = get_var('SDAF_CLEANUP_DRYRUN') ? 0 :
          az_group_delete(name => $group->{name}, timeout => '600')->{rc};

        $group->{result} = $rc ? 'failed' : 'deleted';
        next unless $rc;

        # Set workload zone group with same ID to 'skipped' upon sap_systems failure
        # Destroy attempt would result in failure
        next unless grep { $_ == $group } @sap_systems;
        for my $zone (@workload_zones) {
            $zone->{result} = 'skipped' if $zone->{deployment_id} eq $group->{deployment_id};
        }
    }
}

=head2 destroy_orphaned_resources

    my $cleanup_result = sles4sap::sap_deployment_automation_framework::subscription_cleanup->new();
    $cleanup_result->destroy_orphaned_resources();

Destroys all Deployer VM resources marked as orphaned.

=cut

sub destroy_orphaned_resources ($self) {
    # `az_resource_delete` allows destroying resources only from same RG
    # This groups them together by origin
    # Azure resource group names are case-insensitive. Azure can report the same group with different letter case.
    my %grouped_resources;
    push @{$grouped_resources{lc($_->{resourceGroup})}}, $_ for @{$self->{results}{deployer_vms}};
    my $retries = 5;
    my $rc = undef;
    for my $resource_group (keys %grouped_resources) {
        my $resources = $grouped_resources{$resource_group};
        for my $attempt (1 .. $retries) {
            record_info("Attempt #$attempt", "Resource group: $resource_group");
            if (get_var('SDAF_CLEANUP_DRYRUN')) {
                $rc = 0;
            }
            else {
                $rc = az_resource_delete(
                    resource_group => $resource_group,
                    ids => join(' ', map { $_->{id} } @{$resources}),
                    verbose => 'yes',
                    timeout => '600');
            }
            last unless $rc;
            sleep 30 if $attempt < $retries;    # Avoid command spamming
        }
        $_->{result} = $rc ? 'failed' : 'deleted' for @{$resources};
    }
}

=head2 update_summary

    $cleanup_result->update_summary();

Counts resources in all categories of C<< $self->{results} >> and writes the counters
into C<< $self->{summary} >>. Categories which are not an ARRAYREF are skipped.

=over

=item * B<found>: All resources marked as orphaned

=item * B<deleted>: Resources with result 'deleted'

=item * B<failed>: Resources with result 'failed'

=item * B<skipped>: Resources with result 'skipped'

=back

=cut

sub _update_summary ($self) {
    # Count all result categories. Skip categories which are not implemented yet (undef).
    my @groups = map { @{$self->{results}{$_}} } keys(%{$self->{results}});
    my %count = (deleted => 0, failed => 0, skipped => 0);
    $count{$_->{result}}++ foreach grep { defined($_->{result}) } @groups;

    $self->{summary} = {
        found => scalar(@groups),
        deleted => $count{deleted},
        failed => $count{failed},
        skipped => $count{skipped}
    };
}

=head2 export_cleanup_report

    export_cleanup_report();

Converts report data structure to json and uploads it as a log file

=cut

sub export_cleanup_report ($self) {
    my $tmp_log = '/tmp/cleanup_result.json';
    $self->_update_summary();
    write_sut_file($tmp_log, encode_json({%$self}));
    upload_logs($tmp_log);
    assert_script_run("rm $tmp_log");
}

1;
