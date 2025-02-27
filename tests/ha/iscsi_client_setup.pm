# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: iscsi-client-sles-16
# Summary: Configure iSCSI target for HA tests
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use Utils::Backends qw(is_remote_backend);
use utils qw(zypper_call systemctl ping_size_check);
use testapi;
use hacluster;
use version_utils qw(is_sle package_version_cmp);

sub run {
    my $iscsi_server = get_var('USE_SUPPORT_SERVER') ? 'ns' : get_required_var('ISCSI_SERVER');

    # Perform a ping size check to several hosts which need to be accessible while
    # running this module
    ping_size_check(testapi::host_ip());
    ping_size_check($iscsi_server);

    # open-iscsi & iscsiuio
    if (script_run('rpm -q open-iscsi') != 0) {
        zypper_call 'in open-iscsi';
    }

    record_info('iscsi_client version', script_output('rpm -q open-iscsi'));
    assert_script_run("systemctl start iscsid");
    my $iscsi_daemon_status = script_output("systemctl status iscsid");
    record_info('iscsi_client version', $iscsi_daemon_status);

    my $iqn_node_name = script_output("iscsiadm -m discovery -t st -p 10.0.2.1|grep 'openqa'");
    record_info('iscsi_iqn_node_name', $iqn_node_name);
    my ($node_name) = $iqn_node_name =~ /(\S+)$/;
    record_info('node_name', $node_name);
    assert_script_run("iscsiadm -m node --targetname '$node_name' --op update -n node.startup -v automatic");
    my $persistence = script_output("iscsiadm -m node -T '$node_name' -o show | grep 'node.startup' || echo 'not found'");
    die "iSCSI session persistence is not configured!" unless $persistence =~ /node.startup = automatic/;
    assert_script_run("iscsiadm -m node --targetname '$node_name' --login");
    assert_script_run("iscsiadm -m session");
}

1;
