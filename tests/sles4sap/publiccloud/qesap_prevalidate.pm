# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Check qe-sap-deployment health before start using it.
#
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/publiccloud/qesap_prevalidate.pm - Pre-validation of the deployed environment.

=head1 DESCRIPTION

This module performs health checks on the deployed 'qe-sap-deployment' environment
before proceeding with the main tests. It ensures that the instances are reachable
and that the High Availability (HA) cluster, if enabled, is in a healthy state.

Its primary tasks are:

- Check SSH connectivity to all instances.
- Verify `zypper ref` executes without errors.
- Record the version of `SAPHanaSR-showAttr`.
- Wait for the cluster nodes to sync.
- Identify the Primary and Secondary HANA sites.
- Verify the overall readiness of the cluster (nodes online, no failed resources).

=head1 SETTINGS

=over

=item B<QESAP_PREVALIDATE>

C<legacy> (default) uses the original Perl helpers. C<ansible> runs the HANA
checks once through qe-sap-deployment's sap-hana-prevalidate.yaml and keeps
SSH checks and site mapping in openQA.

=item B<HA_CLUSTER>

A boolean value indicating whether a High Availability cluster is being tested.
If false or 0, cluster-specific checks are skipped.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'sles4sap::publiccloud_basetest';
use testapi;
use publiccloud::utils;
use sles4sap::publiccloud;
use serial_terminal 'select_serial_terminal';
use Mojo::JSON qw(encode_json decode_json);
use version_utils qw(is_sle);
use sles4sap::qesap::qesapdeployment;

use constant RESULT_FILE => '/tmp/qesap-prevalidate.json';
use constant VARS_FILE => '/tmp/qesap-prevalidate-vars.json';

sub test_flags {
    return {fatal => 1};
}

# Run sap-hana-prevalidate.yaml once over all HANA hosts and return its result.
sub _ansible_prevalidate {
    my $angi = get_var('USE_SAP_HANA_SR_ANGI') ? 1 : 0;
    my $vars = encode_json({
            qesap_prevalidate_resource => join('_', $angi ? 'mst' : 'msl', 'SAPHanaCtl',
                get_required_var('INSTANCE_SID'), 'HDB' . get_required_var('INSTANCE_ID')),
            qesap_prevalidate_angi => $angi ? \1 : \0,
            qesap_prevalidate_sle12sp5 => is_sle('=12-SP5') ? \1 : \0,
            qesap_prevalidate_command_timeout => bmwqemu::scale_timeout(60),
            qesap_prevalidate_sync_timeout => bmwqemu::scale_timeout(900),
            qesap_prevalidate_cleanup_timeout => bmwqemu::scale_timeout(300)});

    qesap_ansible_create_section(ansible_section => 'prevalidate',
        section_content => ['sap-hana-prevalidate.yaml -e @' . VARS_FILE]);
    assert_script_run("(umask 077; echo '$vars' > " . VARS_FILE . ')');
    assert_script_run('rm -f ' . RESULT_FILE);

    my %paths = sles4sap::qesap::qesapdeployment::qesap_get_file_paths();
    assert_script_run("cd $paths{deployment_dir}");

    my ($rc, $log) = qesap_execute(
        cmd => 'ansible',
        cmd_options => '-s prevalidate',
        logname => 'qesap_prevalidate.log.txt',
        verbose => 0,
        timeout => bmwqemu::scale_timeout(3600));
    die "Ansible prevalidation failed (rc=$rc); see $log" if $rc;

    my $result = decode_json(script_output('cat ' . RESULT_FILE));
    die 'Incomplete prevalidation result' unless ($result->{promoted} // '') ne '';
    return $result;
}

sub _report {
    my ($result) = @_;
    my $versions = $result->{versions} // {};
    record_info('SAPHanaSR version number',
        join("\n", map { "$_: $versions->{$_}" } sort keys %$versions));
    record_info('crm out', $result->{crm_status_full} // '');
    record_info('Cluster status', $result->{cluster_status}) if $result->{cluster_status};
    foreach my $softfail (@{$result->{softfails} // []}) {
        # Variable named $reference is required by test-soft_failure-no-reference.
        my ($reference, $description) = $softfail =~ /^(\S+)\s*(?:-\s*)?(.*)$/;
        record_soft_failure($reference . ($description ? " - $description" : ''));
    }
}

sub run {
    my ($self, $run_args) = @_;

    # Needed to have peering and ansible state propagated in post_fail_hook
    $self->import_context($run_args);

    my $ha_enabled = get_required_var('HA_CLUSTER') =~ /false|0/i ? 0 : 1;
    my $mode = get_var('QESAP_PREVALIDATE', 'legacy');
    die "Invalid QESAP_PREVALIDATE mode: $mode" unless $mode =~ /\A(?:legacy|ansible)\z/;
    my $use_ansible = $mode eq 'ansible' && $ha_enabled;
    select_serial_terminal;

    my @hana_sites = get_hana_site_names();
    my @hana_instances;
    my $online_string;
    foreach my $instance (@{$self->{instances}}) {
        $self->{my_instance} = $instance;
        # Check ssh connection for all hosts
        $instance->update_instance_ip();
        $instance->wait_for_ssh();

        # Skip instances without HANA db or setup without cluster
        next if ($instance->{instance_id} !~ m/vmhana/) or !$ha_enabled;
        push @hana_instances, $instance;
        next if $use_ansible;

        $self->check_zypper_ref();
        record_info('SAPHanaSR version number', $self->saphanasr_showAttr_version());
        $online_string //= get_online_string($self);
        $self->wait_for_sync(online_string => $online_string);
        record_info('crm out', $self->run_cmd(cmd => 'crm status full', quiet => 1));
        my $master_node = $self->get_promoted_hostname();
        $run_args->{$instance->{instance_id} eq $master_node ? $hana_sites[0] : $hana_sites[1]} = $instance;
    }

    # Exit early if not in cluster scenario
    return unless $ha_enabled;

    if ($use_ansible) {
        my $result = _ansible_prevalidate();
        _report($result);
        foreach my $instance (@hana_instances) {
            $run_args->{$instance->{instance_id} eq $result->{promoted} ? $hana_sites[0] : $hana_sites[1]} = $instance;
        }
    }
    else {
        # Make sure $self->{my_instance} is a hana node
        $self->{my_instance} = $hana_instances[0];
        $self->wait_for_cluster(wait_time => 60, max_retries => 10, online_string => $online_string);
    }

    record_info(
        'Instances:', "Detected HANA instances:
    Site A (PRIMARY): $run_args->{$hana_sites[0]}{instance_id}
    Site B: $run_args->{$hana_sites[1]}{instance_id}"
    );
}

1;
