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
use mmapi qw(get_parents get_current_job_id);
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

=item * ISCSI_LUN_INDEX: if set to C<ondemand>, module will request a number of LUNs to the iSCSI server to be
created on demand. If set to any other value, module will try to connect to a target matching C<openqa>.

=item * CLUSTER_INFOS: when B<ISCSI_LUN_INDEX> is set to C<ondemand>, module extracts number of LUNs to request from
this setting.

=item * NFS_SUPPORT_SHARE: path to NFS share used to share information between nodes.

=item * OPENQA_HOSTNAME: fully qualified name of the openQA instance where the job was scheduled. Used to request the
iSCSI target and LUNs.

=back

=cut

sub request_luns {
    my (%args) = @_;
    foreach (qw(instance jobid numluns)) { die "request_luns: missing [$_] argument" unless $args{$_} }
    zypper_call 'in nfs-client';    # Make sure nfs-client is installed
    assert_script_run 'mount -t nfs ' . get_required_var('NFS_SUPPORT_SHARE') . ' /mnt';
    assert_script_run "mkdir /mnt/ondemand/$args{instance}_$args{jobid}_$args{numluns}";
    assert_script_run 'umount /mnt';
}

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

    record_info 'iscsi initiator pre configuration', script_output('cat /etc/iscsi/initiatorname.iscsi', proceed_on_failure => 1);
    record_info 'rpm-qf', script_output('rpm -qf /etc/iscsi/initiatorname.iscsi', proceed_on_failure => 1);

    # open-iscsi & iscsiuio
    zypper_call 'in open-iscsi' if (script_run('rpm -q open-iscsi'));
    record_info 'iscsi initiator configuration', script_output('cat /etc/iscsi/initiatorname.iscsi');
    record_info 'rpm-qf', script_output('rpm -qf /etc/iscsi/initiatorname.iscsi');
    record_info('open-iscsi version', script_output('rpm -q open-iscsi'));
    my $old_initator_name = script_output("cat /etc/iscsi/initiatorname.iscsi | cut -d '=' -f 2");

    # Generate a new initiatorname for each SUT in case some pre tasks created the same name
    # For sle15sp2 and older versions, the initiatorname can't be changed via '/sbin/iscsi-gen-initiatorname'
    # Use below workaround to generate a new one, we need to apply it for upgrade from sle15sp2 to sle15sp3
    if (is_sle('>=15-SP3') && !check_var('ORIGIN_SYSTEM_VERSION', '15-SP2')) {
        assert_script_run '/sbin/iscsi-gen-initiatorname -f';
    }
    else {
        assert_script_run qq(echo "InitiatorName=`/sbin/iscsi-iname`" | tee /etc/iscsi/initiatorname.iscsi);
    }
    record_info 'iscsi initiator after forcing regeneration', script_output('cat /etc/iscsi/initiatorname.iscsi');
    my $new_initator_name = script_output("cat /etc/iscsi/initiatorname.iscsi | cut -d '=' -f 2");
    die "Initator name $old_initator_name is not changed" if $old_initator_name eq $new_initator_name;

    # Save multipath wwids file as we may need it to blacklist iSCSI devices later
    if (get_var('MULTIPATH')) {
        my $mpconf = '/etc/multipath.conf';
        my $mpwwid = '/etc/multipath/wwids';
        my $mptmp = '/tmp/multipath-wwids';
        script_run "cp $mpwwid $mptmp.orig";
    }

    systemctl 'enable --now iscsid';
    record_info('iscsid status', script_output('systemctl status iscsid'));

    my $iqn_search_string = 'openqa';    # Search iqn names that match 'openqa' by default
    if (check_var('ISCSI_LUN_INDEX', 'ondemand')) {
        # Special value on ISCSI_LUN_INDEX means that we need to request iSCSI LUNs on demand.
        # in that case, iqn will match to node 1's job id
        $iqn_search_string = is_node(1) ? get_current_job_id : (get_parents)->[0];
        die 'Got non-numeric job id' unless ($iqn_search_string =~ m/^\d+$/);
        # Only node 1 will request the LUNs. Number of LUNs to request is the third element in CLUSTER_INFOS
        request_luns(jobid => $iqn_search_string, instance => get_required_var('OPENQA_HOSTNAME'),
            numluns => (split(/:/, get_required_var('CLUSTER_INFOS')))[2]) if is_node(1);
        # Dynamic LUNs provisioning can take some time. We check and wait for up to 10 minutes:
        # 20 retries every 30 seconds = 600 seconds
        script_retry("iscsiadm -m discovery -t st -p '$iscsi_server'|grep -q '$iqn_search_string'", retry => 20,
            fail_message => "Did not see iSCSI target matching [$iqn_search_string] for 10 minutes");
    }

    my $iqn_node_name = script_output("iscsiadm -m discovery -t st -p '$iscsi_server'|grep '$iqn_search_string'");
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

    # Blacklist iSCSI devices in multipath. Otherwise HA tests cannot use them directly
    if (get_var('MULTIPATH') and (get_var('MULTIPATH_CONFIRM') !~ /\bNO\b/i)) {
        assert_script_run "cp $mpwwid $mptmp.new";
        assert_script_run "echo 'blacklist {' >> $mpconf";
        # diff returns 1 when files are different, so we do not assert this call
        my $retval = script_run "diff $mptmp.orig $mptmp.new | sed -n -e 's|/||g' -e 's/> /    wwid /p' >> $mpconf";
        die "Failed to diff [$mptmp.orig] and [$mptmp.new]" unless ($retval == 0 || $retval == 1);
        assert_script_run "echo '}' >> $mpconf";
        assert_script_run "cat $mpconf";
        systemctl('restart multipathd');
    }
}

1;
