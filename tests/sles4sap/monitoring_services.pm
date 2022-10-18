# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Installation and basic tests of exporters for SLES4SAP monitoring
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'sles4sap';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use lockapi;
use Utils::Systemd qw(systemctl);
use utils qw(file_content_replace zypper_call);
use hacluster qw(add_file_in_csync get_cluster_name get_hostname is_node wait_until_resources_started);

sub configure_ha_exporter {
    my $exporter_name = 'ha_cluster_exporter';
    my $metrics_file = "/tmp/${exporter_name}.metrics";

    # Install needed packages
    zypper_call "in prometheus-$exporter_name";

    # Upload the config file (can be in different location)
    upload_logs("/etc/$exporter_name", failok => 1);
    upload_logs("/usr/etc/$exporter_name", failok => 1);

    # Get the IP port and start exporter
    my ($ha_exporter_port) = script_output("awk '/port:/ { print \$NF }' /etc/$exporter_name /usr/etc/$exporter_name 2>/dev/null", proceed_on_failure => 1) =~ /(\d+)/;
    $ha_exporter_port ||= 9664;
    systemctl "enable --now prometheus-$exporter_name";
    systemctl "status prometheus-$exporter_name";
    assert_script_run "curl -o $metrics_file http://localhost:$ha_exporter_port";

    # Export metrics for later analysis
    upload_logs $metrics_file;
}

sub configure_hanadb_exporter {
    my (%args) = @_;
    my $exporter_name = 'hanadb_exporter';
    my $config_dir = "/usr/etc/$exporter_name";
    my $hanadb_exporter_config = "$config_dir/$args{rsc_id}.json";
    my $check_exporter = 'false';
    my $metrics_file = "/tmp/$exporter_name.metrics";
    my $hanadb_exporter_port;

    # Install needed packages (hdcli contains dbapi)
    zypper_call "in prometheus-$exporter_name";
    assert_script_run "pip install \$(ls /hana/shared/$args{instance_sid}/hdbclient/hdbcli-*.tar.gz)";

    # Modify the configuration file
    assert_script_run "cp $config_dir/config.json.example $hanadb_exporter_config";
    file_content_replace("$hanadb_exporter_config",
        q(PASSWORD) => $sles4sap::instance_password,
        q(\./logging_config.ini) => "$config_dir/logging_config.ini",
        q(hanadb_exporter\.log) => "/var/log/${exporter_name}_$args{rsc_id}.log"
    );

    # Upload the config file
    upload_logs("$hanadb_exporter_config", failok => 1);

    # Get the IP port and start exporter
    ($hanadb_exporter_port) = script_output("awk '/exposition_port/ { print \$NF }' $hanadb_exporter_config", proceed_on_failure => 1) =~ /(\d+)/;
    $hanadb_exporter_port ||= 9668;

    # Add monitoring resource in the HA stack
    if (get_var('HA_CLUSTER') and is_node(1)) {
        my $hanadb_msl = "msl_SAPHana_$args{rsc_id}";
        my $hanadb_exp_rsc = "rsc_exporter_$args{rsc_id}";
        $hanadb_exporter_port = 9668;
        $check_exporter = 'true';

        # We need to add the configuration in csync2.conf
        add_file_in_csync(value => "$hanadb_exporter_config");

        # Add the monitoring resource
        assert_script_run(
            'crm configure primitive ' . $hanadb_exp_rsc . " systemd:prometheus-$exporter_name@" . $args{rsc_id}
              . ' op start interval=0 timeout=100'
              . ' op stop interval=0 timeout=100'
              . ' op monitor interval=10'
              . ' meta target-role=Stopped'
        );

        assert_script_run "crm configure colocation col_exporter_$args{rsc_id} +inf: $hanadb_exp_rsc:Started $hanadb_msl:Master";
        assert_script_run "crm resource start $hanadb_exp_rsc";
        wait_until_resources_started;
    } elsif (!get_var('HA_CLUSTER')) {
        $check_exporter = 'true';
        systemctl "enable --now prometheus-$exporter_name\@$args{rsc_id}";
    }

    # Check that the exporter is running
    if ($check_exporter eq 'true') {
        systemctl "status prometheus-$exporter_name\@$args{rsc_id}";
        assert_script_run "curl -o $metrics_file http://localhost:$hanadb_exporter_port";

        # Export metrics for later analysis
        upload_logs $metrics_file;
    }
}

sub configure_sap_host_exporter {
    my (%args) = @_;
    my $exporter_name = 'sap_host_exporter';
    my $default_config = "/etc/$exporter_name/default.yaml";
    my $exporter_config = "/etc/$exporter_name/$args{rsc_id}.yaml";
    my $metrics_file = "/tmp/${exporter_name}.metrics";

    # Install needed packages
    zypper_call "in prometheus-$exporter_name";

    # Modify the configuration file
    assert_script_run "cp $default_config $exporter_config";
    file_content_replace("$exporter_config",
        q(:50013) => ":5$args{instance_id}13"
    );

    # Upload the config file
    upload_logs("$exporter_config", failok => 1);

    # Get the IP port and start exporter
    my ($exporter_port) = script_output("awk '/port:/ { print \$NF }' $exporter_config", proceed_on_failure => 1) =~ /(\d+)/;
    $exporter_port ||= 9680;

    if (get_var('HA_CLUSTER')) {
        my $exporter_rsc = "rsc_exporter_$args{rsc_id}";

        # Use mutex to be sure that only *one* node at a time can access the CIB
        # NOTE: using 'support_server_ready' mutex because it already exists
        #       and because mutex should be created at the beginning on support_server
        mutex_lock 'support_server_ready';

        # We need to add the configuration in csync2.conf
        add_file_in_csync(value => "$exporter_config");

        # Add the monitoring resource
        assert_script_run(
            'crm configure primitive ' . $exporter_rsc . " systemd:prometheus-$exporter_name@" . $args{rsc_id}
              . ' op start interval=0 timeout=100'
              . ' op stop interval=0 timeout=100'
              . ' op monitor interval=10'
              . ' meta target-role=Stopped'
        );
        assert_script_run "crm configure modgroup grp_$args{rsc_id} add $exporter_rsc";
        assert_script_run "crm resource start $exporter_rsc";
        wait_until_resources_started;

        # Release the lock
        mutex_unlock 'support_server_ready';
    } else {
        # Start exporter
        systemctl "enable --now prometheus-$exporter_name\@$args{rsc_id}";
    }

    # Check that the exporter is running
    systemctl "status prometheus-$exporter_name\@$args{rsc_id}";
    assert_script_run "curl -o $metrics_file http://localhost:$exporter_port";

    # Export metrics for later analysis
    upload_logs $metrics_file;
}

sub configure_node_exporter {
    my $monitoring_port = 9100;
    my $metrics_file = '/tmp/node_exporter.metrics';

    # Install and start node_exporter
    zypper_call 'in golang-github-prometheus-node_exporter';
    systemctl 'enable --now prometheus-node_exporter';
    systemctl 'status prometheus-node_exporter';

    # Check that node_exporter is working as expected
    assert_script_run "curl -o $metrics_file http://localhost:$monitoring_port/metrics";

    # Export metrics for later analysis
    upload_logs $metrics_file;
}

sub run {
    my ($self) = @_;
    my $hostname = get_hostname;
    my $cluster_name = get_cluster_name;
    my $instance_sid = get_required_var('INSTANCE_SID');
    my $instance_type = get_required_var('INSTANCE_TYPE');
    my $instance_id = get_required_var('INSTANCE_ID');
    my $rsc_id = "${instance_sid}_${instance_type}${instance_id}";

    # Make sure that we have an opened terminal
    select_serial_terminal;

    # Configure Exporters
    configure_ha_exporter if get_var('HA_CLUSTER');
    configure_hanadb_exporter(rsc_id => $rsc_id, instance_sid => $instance_sid) if get_var('HANA');
    configure_sap_host_exporter(rsc_id => $rsc_id, instance_id => $instance_id) if get_var('NW');
    barrier_wait "MONITORING_CONF_DONE_$cluster_name" if get_var('HA_CLUSTER');    # Synchronize the nodes if needed
    configure_node_exporter;

}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
