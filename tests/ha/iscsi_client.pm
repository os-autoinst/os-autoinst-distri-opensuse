# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-iscsi-client
# Summary: Configure iSCSI target for HA tests
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use Utils::Backends qw(is_remote_backend);
use utils qw(zypper_call systemctl);
use testapi;
use hacluster;
use version_utils qw(is_sle);

sub run {
    # Some remote backends connect to the root-console via sshXtermVt or ipmiXtermVt,
    # which set DISPLAY and cause yast2 to show its graphical version. This unsets
    # DISPLAY so the terminal version is shown instead when testing in textmode
    assert_script_run 'unset DISPLAY' if (check_var('DESKTOP', 'textmode') && is_remote_backend());

    # Restart udevd if hostname was changed. This is needed at least in 15-SP3+, but it should
    # be safe for older versions as well. See comment 15 in bsc#1177927 for details
    systemctl 'restart systemd-udevd' if get_var('HOSTNAME');

    # Save multipath wwids file as we may need it to blacklist iSCSI devices later
    my $mpconf = '/etc/multipath.conf';
    my $mpwwid = '/etc/multipath/wwids';
    my $mptmp = '/tmp/multipath-wwids';
    script_run "cp $mpwwid $mptmp.orig";

    # Installation of iSCSI client package(s) if needed
    zypper_call 'in --recommends yast2-iscsi-client';

    # open-iscsi & iscsiuio were dropped as dependencies for yast2-iscsi-client. See gh#yast/yast-iscsi-client#121
    if (script_run('rpm -q open-iscsi iscsiuio')) {
        # Verify if the recommendation was added to the release notes in SLES 15-SP5
        my $reln_chk = is_sle('15-SP5+') ? script_run('curl --silent https://www.suse.com/releasenotes/' .
              get_required_var('ARCH') . '/SUSE-SLES/15-SP5/index.html | grep -q bsc-1204978') : 1;
        record_soft_failure 'bsc#1204528 bsc#1204978 - Some yast2-iscsi-client dependencies were not installed with --recommends' if $reln_chk;
        zypper_call 'in open-iscsi iscsiuio';
    }

    # Configuration of iSCSI client
    script_run("yast2 iscsi-client; echo yast2-iscsi-client-status-\$? > /dev/$serialdev", 0);
    assert_screen 'iscsi-client-overview-service-tab', $default_timeout;
    send_key 'alt-b';    # Start iscsi daemon on Boot
    wait_still_screen 3;
    send_key 'alt-i';    # Initiator name
    wait_still_screen 3;
    for (1 .. 40) { send_key 'backspace'; }
    type_string 'iqn.1996-04.de.suse:01:' . get_hostname . '.' . get_cluster_name;
    wait_still_screen 3;
    send_key 'alt-v';    # discoVered targets
    wait_still_screen 3;

    # Go to Discovered Targets screen can take time
    assert_screen 'iscsi-client-discovered-targets', 120;
    send_key_until_needlematch 'iscsi-client-discovery', 'alt-d';
    assert_screen 'iscsi-client-discovery';
    send_key 'alt-i';    # Ip address
    wait_still_screen 3;
    my $iscsi_server = get_var('USE_SUPPORT_SERVER') ? 'ns' : get_required_var('ISCSI_SERVER');
    type_string $iscsi_server;
    wait_still_screen 3;
    send_key 'alt-n';    # Next

    # Sometimes client connection does not work immediately
    wait_still_screen 10;
    # Select target with internal IP first?
    assert_screen 'iscsi-client-target-list';
    send_key 'alt-e';    # connect
    assert_screen 'iscsi-client-target-startup';
    send_key_until_needlematch 'iscsi-client-target-startup-manual-selected', 'alt-s';
    send_key_until_needlematch 'iscsi-client-target-startup-automatic-selected', 'down';
    assert_screen 'iscsi-client-target-startup-automatic-selected';
    send_key 'ret';
    wait_still_screen 3;
    send_key 'alt-n';    # Next

    # Go to Discovered Targets screen can take time
    assert_screen 'iscsi-client-target-connected', 120;
    send_key 'alt-o';    # Ok
    wait_still_screen 3;
    wait_serial('yast2-iscsi-client-status-0', 90) || die "'yast2 iscsi-client' didn't finish";

    if (is_sle('=15-SP1') && systemctl('-q is-active iscsi', ignore_failure => 1)) {
        record_soft_failure('iscsi issue: bug bsc#1162078');
        systemctl('start iscsi');
    }

    # iSCSI LUN must be present
    assert_script_run 'ls -1 /dev/disk/by-path/ip-*-lun-*';

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
