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

C<legacy> (default) uses the original Perl helpers. C<ansible> runs the same
host and cluster stages through sap-hana-prevalidate.yaml. The module keeps
instance ordering, SSH checks, site mapping and failure context in openQA.
Use a qe-sap-deployment revision that supplies the playbook before enabling it.

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

# Run one stage through qesap.py; the scheduled test keeps instance mapping.
sub _ansible_prevalidate {
    my ($hostname, $phase) = @_;
    my $angi = get_var('USE_SAP_HANA_SR_ANGI') ? 1 : 0;
    my $options = encode_json({
            node_name => $hostname, qesap_prevalidate_phase => $phase,
            qesap_prevalidate_resource => join('_', $angi ? 'mst' : 'msl', 'SAPHanaCtl',
                get_required_var('INSTANCE_SID'), 'HDB' . get_required_var('INSTANCE_ID')),
            qesap_prevalidate_angi => $angi,
            qesap_prevalidate_sle12sp5 => is_sle('=12-SP5') ? 1 : 0,
            qesap_prevalidate_command_timeout => bmwqemu::scale_timeout(60),
            qesap_prevalidate_sync_timeout => bmwqemu::scale_timeout(900),
            qesap_prevalidate_cleanup_timeout => bmwqemu::scale_timeout(300)});
    my %paths = sles4sap::qesap::qesapdeployment::qesap_get_file_paths();
    my $directory = $paths{deployment_dir};
    # Quote both values before passing them to the controller shell.
    s/'/'"'"'/g for ($options, $directory);
    (my $logname = "qesap-prevalidate-$hostname-$phase.log.txt") =~ s/[^A-Za-z0-9_.-]/_/g;
    assert_script_run("(umask 077; printf '%s' '$options' > /tmp/qesap-prevalidate-vars.json)");
    assert_script_run("rm -f /tmp/qesap-prevalidate.json /tmp/00-ansible-$logname");
    assert_script_run("cd '$directory'");
    my ($rc, $log) = qesap_execute(cmd => 'ansible', cmd_options => '-s prevalidate --skip-bootstrap',
        logname => $logname, verbose => 0,
        # Cover nested command timeouts and unscaled sleeps; inner waits stay bounded.
        timeout => bmwqemu::scale_timeout(12000) + 1800);
    qesap_ansible_softfail(logfile => $log);
    die "Ansible prevalidation failed (rc=$rc); see $log" if $rc;
    return if $phase eq 'cluster';
    my $result = decode_json(script_output('cat /tmp/qesap-prevalidate.json'));
    die 'Missing prevalidation host result' unless ref($result) eq 'HASH'
      && defined($result->{version}) && ($result->{promoted} // '') ne '';
    return $result;
}

sub test_flags {
    return {fatal => 1};
}

sub run {
    my ($self, $run_args) = @_;

    # Needed to have peering and ansible state propagated in post_fail_hook
    $self->import_context($run_args);

    my $ha_enabled = get_required_var('HA_CLUSTER') =~ /false|0/i ? 0 : 1;
    select_serial_terminal;
    my $validation_mode = get_var('QESAP_PREVALIDATE', 'legacy');
    die "Invalid QESAP_PREVALIDATE mode: $validation_mode" unless $validation_mode =~ /\A(?:legacy|ansible)\z/;
    qesap_ansible_create_section(ansible_section => 'prevalidate',
        section_content => ['sap-hana-prevalidate.yaml -e @/tmp/qesap-prevalidate-vars.json'])
      if $validation_mode eq 'ansible' && $ha_enabled;

    # Check connectivity to all instances and status of the cluster in case of HA deployment
    my @hana_sites = get_hana_site_names();
    # Cache the online_string to avoid repeated SSH calls to pacemaker_version() (version is cluster-wide constant)
    my $online_string;
    foreach my $instance (@{$self->{instances}}) {
        $self->{my_instance} = $instance;
        my $instance_id = $instance->{'instance_id'};
        # Check ssh connection for all hosts
        $instance->update_instance_ip();
        $instance->wait_for_ssh();

        # Skip instances without HANA db or setup without cluster
        next if ($instance_id !~ m/vmhana/) or !$ha_enabled;

        my $master_node;
        if ($validation_mode eq 'ansible') {
            my $result = _ansible_prevalidate($instance_id, 'host');
            record_info('SAPHanaSR version number', $result->{version});
            $master_node = $result->{promoted};
        }
        else {
            $self->check_zypper_ref();
            record_info('SAPHanaSR version number', $self->saphanasr_showAttr_version());
            $online_string //= get_online_string($self);
            $self->wait_for_sync(online_string => $online_string);
            my $resource_output = $self->run_cmd(cmd => "crm status full", quiet => 1);
            record_info("crm out", $resource_output);
            $master_node = $self->get_promoted_hostname();
        }

        if ($instance_id eq $master_node) {
            $run_args->{$hana_sites[0]} = $instance;
        }
        else {
            $run_args->{$hana_sites[1]} = $instance;
        }
    }

    # Exit early if not in cluster scenario
    return unless $ha_enabled;

    # Check cluster for overall readiness (nodes online, in sync and crm output contains no failed resources)
    # First make sure that instance in $self->{my_instance} is a hana node
    foreach my $instance (@{$self->{instances}}) {
        $self->{my_instance} = $instance;
        last if ($instance->{instance_id} =~ m/vmhana/);
    }
    if ($validation_mode eq 'ansible') {
        _ansible_prevalidate($self->{my_instance}{instance_id}, 'cluster');
    }
    else {
        $self->wait_for_cluster(wait_time => 60, max_retries => 10, online_string => $online_string);
    }

    record_info(
        'Instances:', "Detected HANA instances:
    Site A (PRIMARY): $run_args->{$hana_sites[0]}{instance_id}
    Site B: $run_args->{$hana_sites[1]}{instance_id}"
    );
}

1;
