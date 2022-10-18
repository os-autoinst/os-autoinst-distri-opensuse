# SUSE's SLES4SAP openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test sap_suse_cluster_connector command
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base "sles4sap";
use testapi;
use serial_terminal 'select_serial_terminal';
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

    assert_script_run("$args{binary} $cmd", timeout => $timeout);
    if ($args{log_file}) {
        my $output = script_output("cat $args{log_file}", proceed_on_failure => 1);
        record_info("Command output", "$output");
        return $output;
    }
}

sub run {
    my ($self) = @_;
    my $instance_type = get_required_var('INSTANCE_TYPE');
    my $instance_id = get_required_var('INSTANCE_ID');
    my $instance_sid = get_required_var('INSTANCE_SID');
    my $binary = 'sap_suse_cluster_connector';
    my $log_file = "/tmp/${binary}_out.log";

    # No need to test this cluster specific part if there is no HA
    return unless get_var('HA_CLUSTER');

    select_serial_terminal;

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
        exec_conn_cmd(binary => $binary, cmd => "smm --sid $instance_sid --ino $instance_id --mod $mod", log_file => $log_file);
        # Wait to let enough time for the HA stack to change Maintenance Mode
        sleep 10;
    }

    # List nodes
    my @resources = get_var('NW') ? ('ip', 'fs', 'sap') : ('ip', 'SAPHanaTopology', 'SAPHana');
    foreach my $rsc_type (@resources) {
        my $rsc = "rsc_${rsc_type}_${instance_sid}_${instance_type}${instance_id}";
        exec_conn_cmd(binary => $binary, cmd => "lsn --res $rsc", log_file => $log_file);
    }

    # Test Stop/Start of SAP resource
    my $rsc = get_var('NW') ? "rsc_sap_${instance_sid}_${instance_type}${instance_id}" : "rsc_SAPHana_${instance_sid}_${instance_type}${instance_id}";
    exec_conn_cmd(binary => $binary, cmd => "$_ --res $rsc --act stop", timeout => 120) foreach qw(fra cpa);
    wait_until_resources_stopped(timeout => 1200);
    save_state;    # do a check of the cluster with a screenshot
    exec_conn_cmd(binary => $binary, cmd => "$_ --res $rsc --act start", timeout => 120) foreach qw(fra cpa);

    # Wait for the resources to be restarted
    wait_until_resources_started(timeout => 1200);

    # Check for the state of the whole cluster
    check_cluster_state;
}

1;
