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
use utils qw(zypper_call systemctl ping_size_check file_content_replace script_retry);
use testapi;
use hacluster;
use serial_terminal qw(select_serial_terminal);
use version_utils qw(is_sle package_version_cmp);

sub run {
    return record_info('Skip iscsi_client_setup', 'Module skipped on older versions of SLES. Use ha/iscsi_client instead') if (is_sle('<16'));
    my $iscsi_server = get_var('USE_SUPPORT_SERVER') ? 'ns' : get_required_var('ISCSI_SERVER');
    my $iscsi_conf = '/etc/iscsi/iscsid.conf';

    select_serial_terminal;

    # Perform a ping size check to several hosts which need to be accessible while
    # running this module
    ping_size_check(testapi::host_ip());
    ping_size_check($iscsi_server);

    # open-iscsi & iscsiuio
    zypper_call 'in open-iscsi' if (script_run('rpm -q open-iscsi'));
    record_info('open-iscsi version', script_output('rpm -q open-iscsi'));

    # Change node.startup to automatic
    file_content_replace($iscsi_conf, 'node.startup = manual' => 'node.startup = automatic');
    record_info('iscsi startup', script_output("grep node.startup $iscsi_conf"));

    systemctl 'enable --now iscsid';
    record_info('iscsid status', script_output('systemctl status iscsid'));

    my $iqn_node_name = script_output("iscsiadm -m discovery -t st -p '$iscsi_server'|grep 'openqa'");
    record_info('iscsi_iqn_node_name', $iqn_node_name);
    my ($node_name) = $iqn_node_name =~ /(\S+)$/;
    record_info('node_name', $node_name);

    assert_script_run "iscsiadm --mode node --target '$node_name' --portal $iscsi_server -o new";
    assert_script_run "iscsiadm --mode node --target '$node_name' --portal $iscsi_server -n discovery.sendtargets.use_discoveryd -v Yes";
    assert_script_run "iscsiadm --mode node --target '$node_name' --portal $iscsi_server -n discovery.sendtargets.discoveryd_poll_inval -v 30";
    systemctl "restart $_" foreach qw(iscsid iscsi);
    record_info('iscsi status', script_output('systemctl --no-pager status iscsid iscsi'));

    my $persistence = script_output("iscsiadm -m node -T '$node_name' -o show | grep 'node.startup' || echo 'not found'");
    die 'iSCSI session persistence is not configured!' unless $persistence =~ /node.startup = automatic/;

    # Check iSCSI devices are there or fail if missing. Check more than once, as serial terminal
    # could run commands faster than SUT is able to access the devices
    script_retry('ls /dev/disk/by-path/ip-*', timeout => $default_timeout, retry => 5, delay => 10, fail_message => 'No iSCSI devices!');
}

1;
