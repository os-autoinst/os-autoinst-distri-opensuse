# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: open-iscsi, iscsiuio
# Summary: Configure iSCSI target for HA tests
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'haclusterbasetest';
use Utils::Backends qw(is_remote_backend);
use utils qw(zypper_call systemctl ping_size_check file_content_replace script_retry);
use testapi;
use hacluster;
use serial_terminal qw(select_serial_terminal);
use version_utils qw(is_sle package_version_cmp);

=head1 NAME

ha/iscsi_client_setup.pm - Add iSCSI targets to the System Under Test

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=head1 DESCRIPTION

Configure iSCSI targets from a known iSCSI server in the System Under Test using CLI commands.

B<The key tasks performed by this module include:>

=over

=item * Verify the test module runs in SLES 16 or older. Skip in older versions.

=item * Restart C<systemd-udevd> service.

=item * Verify the iSCSI server is reachable.

=item * Record iSCSI initiator value.

=item * Install C<open-iscsi> and C<iscsiuio>

=item * Generate a new initiator

=item * Enable and start C<iscsid> service.

=item * Query a list of IQN nodes from the iSCSI server, and select one that matches to the C<openqa> string.

=item * Change the startup of the IQN node name from C<manual> to C<automatic> in the C<default>
configuration file generated after discovery.

=item * Start a new session to the IQN node name in the iSCSI server.

=item * Restart C<iscsid> and C<iscsi> services.

=item * Verify there are new block devices starting with the text C<ip-> in the SUT.

=back

=head1 OPENQA SETTINGS

=over

=item * USE_SUPPORT_SERVER: indicates whether test runs in a Multi Machine scenario with a Support Server.

=item * ISCSI_SERVER: IP address or FQHN of the iSCSI server.

=back

=cut

sub run {
    my $iscsi_server = get_var('USE_SUPPORT_SERVER') ? 'ns' : get_required_var('ISCSI_SERVER');

    select_serial_terminal;

    # Restart udevd in SLES 16, as it comes configured with
    # ProtectHostname=yes, meaning that the hostname seen by
    # udevd and the one configured in the system may differ in
    # scenarios where console/hostname is also scheduled which
    # can lead to issues later with some HA resources. We need to
    # do this before iSCSI and watchdog setup.
    # Keep it running for SLES 12/15 in case hostname is changed
    systemctl 'restart systemd-udevd.service';

    # Perform a ping size check to several hosts which need to be accessible while
    # running this module
    ping_size_check(testapi::host_ip());
    ping_size_check($iscsi_server);

    # open-iscsi & iscsiuio
    zypper_call 'in open-iscsi' if (script_run('rpm -q open-iscsi'));
    record_info 'iscsi initiator pre configuration', script_output('cat /etc/iscsi/initiatorname.iscsi', proceed_on_failure => 1);
    record_info 'rpm-qf', script_output('rpm -qf /etc/iscsi/initiatorname.iscsi', proceed_on_failure => 1);
    record_info('open-iscsi version', script_output('rpm -q open-iscsi'));

    # Generate a new initiatorname for each SUT in case some pre tasks created the same name
    if (is_sle('>=15')) {
        assert_script_run '/sbin/iscsi-gen-initiatorname -f';
    }
    else {
        # For sle12, the initiatorname can't be changed via '/sbin/iscsi-gen-initiatorname'
        # Use below workaround to generate a new one
        assert_script_run qq(echo "InitiatorName=`/sbin/iscsi-iname`" | tee /etc/iscsi/initiatorname.iscsi);
    }
    record_info 'iscsi initiator after forcing regeneration', script_output('cat /etc/iscsi/initiatorname.iscsi', proceed_on_failure => 1);
    systemctl 'enable --now iscsid';
    record_info('iscsid status', script_output('systemctl status iscsid'));

    my $iqn_node_name = script_output("iscsiadm -m discovery -t st -p '$iscsi_server'|grep 'openqa'");
    record_info('iscsi_iqn_node_name', $iqn_node_name);
    my ($node_name) = $iqn_node_name =~ /(\S+)$/;
    record_info('node_name', $node_name);

    # Change node.startup to automatic
    my $iscsi_dir = is_sle('>=16') ? "/var/lib/iscsi" : "/etc/iscsi";
    my $iscsi_conf = "$iscsi_dir/nodes/$node_name/*/default";
    assert_script_run "ls -l $iscsi_conf";
    file_content_replace($iscsi_conf, 'node.startup = manual' => 'node.startup = automatic');
    record_info('iscsi startup', script_output("grep node.startup $iscsi_conf"));

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
