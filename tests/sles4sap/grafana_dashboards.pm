# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic tests for HA & SAP grafana dashboards
# Maintainer: QE-SAP <qe-sap@suse.de>

use base "sles4sap";
use testapi;
use strict;
use warnings;
use hacluster qw(get_my_ip);
use registration;
use utils qw(zypper_call systemctl);

sub run {
    my ($self) = @_;
    my $grafana_log = '/var/log/grafana/grafana.log';
    my $ip = get_my_ip();
    my $timeout = bmwqemu::scale_timeout(30);

    # Register the PackageHub module and install Grafana
    add_suseconnect_product(get_addon_fullname('phub'));
    zypper_call("in grafana");

    # Install HA & SAP grafana dashboards
    zypper_call("in grafana-ha-cluster-dashboards grafana-sap-hana-dashboards grafana-sap-netweaver-dashboards");
    systemctl 'start grafana-server.service';
    systemctl '-l status grafana-server.service';
    upload_logs "$grafana_log";

    # Check if all the dashboards are loaded when the grafana server starts
    if (script_run "(( \$(grep -c 'failed to load dashboard' $grafana_log) == 0 ))") {
        my $failed_dashboard = script_output "awk -F'/|.json' '/failed to load dashboard from/ {print \$7}' $grafana_log | sort -u";
        $failed_dashboard =~ tr{\n}{ };
        record_info("Dashboard error", "Failed to load dashboard(s): $failed_dashboard");
        die 'One or more dashboards failed to load, check the grafana log for details';
    }

    # Basic graphical tests
    select_console 'displaymanager';
    $self->handle_displaymanager_login();
    x11_start_program("firefox --private-window http://$ip:3000", target_match => 'grafana-login', match_timeout => $timeout);
    type_string "admin";
    send_key 'tab';
    type_string "admin";
    send_key 'tab';
    send_key 'ret';
    assert_screen "new-password", $timeout;
    type_password;
    send_key 'tab';
    type_password;
    send_key 'tab';
    send_key 'ret';
    assert_and_click "grafana-home", timeout => $timeout;
    assert_and_click "select_suse-dashboard", timeout => $timeout;
    assert_screen "check_suse-dashboard", $timeout;

    # Close the browser and back to the desktop
    send_key 'alt-f4';
    assert_screen('generic-desktop');
}

1;
