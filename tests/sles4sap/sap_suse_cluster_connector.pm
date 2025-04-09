# SUSE's SLES4SAP openQA tests
#
# Copyright 2019, 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test sap_suse_cluster_connector command
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'sles4sap';
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils qw(is_sle);
use hacluster;
use strict;
use warnings;

=head2 exec_conn_cmd

Execute the C<sap_suse_cluster_connector> command with
the provided C<command> and log the results in the
also provided C<logfile>.

=cut
sub exec_conn_cmd {
    my %args = @_;
    my $timeout = $args{timeout} // $bmwqemu::default_timeout;
    my $cmd = $args{cmd};
    $cmd .= " --out $args{log_file}" if ($args{log_file});

    script_run("rm -f $args{log_file}") if ($args{log_file});
    assert_script_run("$args{binary} $cmd", timeout => $timeout);
    if ($args{log_file}) {
        my $output = script_output("cat $args{log_file}", proceed_on_failure => 1);
        record_info("Command output", "$output");
        return $output;
    }
}

sub run {
    my $instance_type = get_required_var('INSTANCE_TYPE');
    my $instance_id = get_required_var('INSTANCE_ID');
    my $instance_sid = get_required_var('INSTANCE_SID');
    my $binary = 'sap_suse_cluster_connector';
    my $log_file = "/tmp/${binary}_out.log";

    # No need to test this cluster specific part if there is no HA
    return unless get_var('HA_CLUSTER');

    # Module needs to run in root console before SLES 15
    is_sle('15+') ? select_serial_terminal : select_console 'root-console';

    # Check the version
    my $package_version = script_output "rpm -q --qf '%{VERSION}' sap-suse-cluster-connector";
    my $output = exec_conn_cmd(binary => $binary, cmd => 'gvi', log_file => $log_file);

    # Record the soft failure if the version number differs
    record_soft_failure('bsc#1156661 - Version number mismatch') unless ($output =~ /\($binary $package_version\)/);

    # Check HA config and list resources
    my @commands = get_var('NW') ? qw(hcc lsr) : qw(hcc);
    exec_conn_cmd(binary => $binary, cmd => "$_ --sid $instance_sid --ino $instance_id", log_file => $log_file) foreach (@commands);

    # Test Maintenance Mode
    foreach my $mod (1, 0) {
        my $retval = exec_conn_cmd(binary => $binary, cmd => "smm --sid $instance_sid --ino $instance_id --mod $mod", log_file => $log_file);
        # Return code in general:
        # 0: successfull command termination or "yes" to a yes-no-query
        # 1: unsucessfull command termination or "no" to a yes-no-query
        # 2: error occurred during command termination - mostly bad parameters
        die "Commad 'smm' failed and returns $retval" if ($retval == 2);
        # Wait to let enough time for the HA stack to change Maintenance Mode
        wait_for_idle_cluster;
    }

    # List nodes
    my @hana_resources = get_var('USE_SAP_HANA_SR_ANGI') ? ('ip', 'SAPHanaFil', 'SAPHanaTpg', 'SAPHanaCtl') : ('ip', 'SAPHanaTpg', 'SAPHanaCtl');
    my @resources = get_var('NW') ? ('ip', 'fs', 'sap') : @hana_resources;
    foreach my $rsc_type (@resources) {
        my $rsc = "rsc_${rsc_type}_${instance_sid}_$instance_type$instance_id";
        wait_for_idle_cluster;
        exec_conn_cmd(binary => $binary, cmd => "lsn --res $rsc", log_file => $log_file);
        # Check the "node list" contains localhost
        my $hostname = get_required_var('HOSTNAME');
        validate_script_output("cat $log_file | cut -d : -f 4", sub { m/$hostname/ });
        record_info("Found $hostname in lsn output");
        # Check the "node list" contains remote node
        my $remote_node = choose_node(2);
        validate_script_output("cat $log_file | cut -d : -f 4", sub { m/$remote_node/ });
        record_info("Found $remote_node in lsn output");
    }

    # Test Stop/Start of SAP resource
    my $hana_resource_name = $sles4sap::resource_alias . "_SAPHanaCtl_${instance_sid}_$instance_type$instance_id";
    my $rsc = get_var('NW') ? "rsc_sap_${instance_sid}_$instance_type$instance_id" : $hana_resource_name;
    wait_for_idle_cluster;
    exec_conn_cmd(binary => $binary, cmd => "$_ --res $rsc --act stop", timeout => 120) foreach qw(fra cpa);
    wait_until_resources_stopped(timeout => 1200);
    save_state;    # do a check of the cluster with a screenshot
    wait_for_idle_cluster;
    exec_conn_cmd(binary => $binary, cmd => "$_ --res $rsc --act start", timeout => 120) foreach qw(fra cpa);

    # Wait for the resources to be restarted
    wait_until_resources_started(timeout => 1200);
    save_state;    # do a check of the cluster with a screenshot
    assert_script_run 'crm_resource --cleanup';

    # Check for the state of the whole cluster
    check_cluster_state;
}

1;
