# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-iscsi-client open-iscsi lsscsi util-linux e2fsprogs
# Summary: Test suite for iSCSI server and client
#    Multimachine testsuites, server test creates iscsi target and client test uses it
# - Configure a static network and test connectivity
# - Launch yast2 iscsi client wizard
# - Check iscsid systemd services and general disk status
# - Partition (if necessary) and format iscsi drive
# - Try mount remote partition to /mnt
# - Write text to file on iscsi disk
# - Grep expected text from file
# - Create mutex lock
# - Cleanup
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use lockapi qw(mutex_create mutex_wait);
use version_utils qw(is_sle is_leap);
use yast2_widget_utils 'change_service_configuration';
use utils qw(systemctl type_string_slow_extended zypper_call);
use scheduler 'get_test_suite_data';
use y2_mm_common 'prepare_xterm_and_setup_static_network';
use YaST::workarounds;
use Utils::Logging 'save_and_upload_log';

# load expected test data from yaml
# common for both iscsi MM modules
my $test_data = get_test_suite_data();

sub initiator_service_tab {
    unless (is_sle('<15') || is_leap('<15.1')) {
        if (is_sle('=15')) {
            change_service_configuration(
                after_reboot => {start_on_boot => 'alt-b'}
            );
        } else {
            change_service_configuration(
                after_writing => {start => 'alt-f'},
                after_reboot => {start_on_demand => 'alt-a'}
            );
        }
    }
    # go to initiator name field
    send_key "alt-i";
    type_string_slow_extended($test_data->{initiator_conf}->{name} . ':' . $test_data->{initiator_conf}->{id});
    assert_screen 'iscsi-initiator-service';
}

sub initiator_discovered_targets_tab {
    # go to discovered targets tab
    send_key "alt-v";
    assert_screen 'iscsi-discovered-targets', 120;
    # press discovery button
    send_key "alt-d";
    wait_still_screen(2);
    assert_screen 'iscsi-discovery';
    # go to IP address field
    send_key "alt-i";
    my $target_ip_only = (split('/', $test_data->{target_conf}->{ip}))[0];
    type_string_slow_extended $target_ip_only;
    apply_workaround_bsc1204176('iscsi-initiator-discovered-IP-adress') if (is_sle('>=15-SP4'));
    assert_screen 'iscsi-initiator-discovered-IP-adress';
    # next and press connect button
    send_key "alt-n";
    assert_and_click 'iscsi-initiator-connect-button';
    send_key_until_needlematch 'iscsi-initiator-connect-automatic', 'down';
    send_key 'alt-o';
    assert_screen 'iscsi-initiator-discovery-enable-login-auth';
    send_key 'alt-u';
    type_string_slow_extended $test_data->{initiator_conf}->{user};
    assert_screen 'iscsi-initiator-discovery-auth-initiators-username';
    send_key 'alt-p';
    my $init_pass = reverse $test_data->{common}->{password};
    wait_screen_change { type_string_slow_extended $init_pass; };
    send_key 'alt-r';
    type_string_slow_extended $test_data->{target_conf}->{user};
    assert_screen 'iscsi-initiator-discovery-auth-targets-username';
    send_key 'alt-a';
    wait_screen_change { type_string_slow_extended $test_data->{common}->{password}; };
    send_key 'alt-n';
}

sub initiator_connected_targets_tab {
    # go to discovered targets tab
    send_key "alt-d";
    wait_still_screen(2);
    apply_workaround_bsc1204176('iscsi-initiator-discovered-targets') if (is_sle('>=15-SP4'));
    assert_screen 'iscsi-initiator-discovered-targets';
    # go to connected targets tab
    send_key "alt-n";
    assert_screen 'iscsi-initiator-connected-targets';
    # press OK twice
    send_key "alt-o";
    wait_still_screen(2, 10);
    send_key "alt-o";
}


sub run {
    prepare_xterm_and_setup_static_network(ip => $test_data->{initiator_conf}->{ip}, message => 'Configure MM network - client');
    zypper_call("in yast2-iscsi-client");
    mutex_wait('iscsi_target_ready', undef, 'Target configuration in progress!');
    record_info 'Target Ready!', 'iSCSI target is configured, start initiator configuration';
    my $module_name = y2_module_guitest::launch_yast2_module_x11('iscsi-client', target_match => 'iscsi-client');
    initiator_service_tab;
    initiator_discovered_targets_tab;
    initiator_connected_targets_tab;
    wait_serial("yast2-iscsi-client-status-0", 180) || die "'yast2 iscsi-client ' didn't finish or exited with non-zero code";
    # logging in to a target will create a local disc device
    # it takes a moment, since udev actually handles it
    sleep 5;
    record_info 'Systemd', 'Verify status of iscsi services and sockets';
    systemctl("is-active iscsid.service");
    systemctl("is-active iscsid.socket");
    if (!is_sle('=12-SP4') && !is_sle('=12-SP5')) {
        systemctl("is-active iscsi.service");
    }
    record_info 'Display iSCSI session';
    assert_script_run 'iscsiadm --mode session -P 3 | tee -a ' . "/dev/$serialdev | grep LOGGED_IN";
    record_info 'Verify LUN availability';
    my $backstore_model = ($test_data->{target_conf}->{backstore_type} eq 'fileio') ? 'fileio' : 'iblock';
    assert_script_run "lsscsi | tee -a /dev/$serialdev | grep -i $backstore_model";
    assert_script_run "lsblk --scsi | tee -a /dev/$serialdev | grep -i $backstore_model";
    assert_script_run 'ls /dev/disk/by-path |grep ' . $test_data->{target_conf}->{name} . ':' . $test_data->{target_conf}->{id};
    # filter out iscsi drive according to TRAN column
    my $iscsi_drive = script_output "lsblk --scsi -p | grep iscsi | awk '{print \$1}'";
    # making a single partition actually causes the kernel code to re-read the starting part of the disc
    # in order for it to recognize that you now have a partition table when before there was none
    # create one partition and format it to ext4
    # lvm does not need a partition, we can deploy fs directly on lvm
    unless ($test_data->{target_conf}->{backstore_type} eq 'lvm') {
        assert_script_run "echo -e \"n\\np\\n1\\n\\n\\nw\\n\" \| fdisk $iscsi_drive";
        $iscsi_drive .= '1';
    }
    sleep 3;
    assert_script_run "mkfs.ext4 $iscsi_drive";
    sleep 2;
    # try mount remote partition to /mnt
    assert_script_run "mount $iscsi_drive /mnt";
    # write text to file on iscsi disk
    assert_script_run 'echo "iscsi is working" > /mnt/iscsi';
    # grep expected text from file
    assert_script_run 'grep "iscsi is working" /mnt/iscsi';
    mutex_create('iscsi_initiator_ready');
    mutex_wait('iscsi_display_sessions', undef, 'Verifying sessions on target');
    record_info 'Logout iSCSI', 'Logout iSCSI sessions & unmount LUN';
    assert_script_run 'iscsiadm --mode node --logoutall=all';
    assert_script_run 'umount /mnt';
    enter_cmd "killall xterm";
}

sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook;
    save_and_upload_log("iscsiadm --mode session -P 3", "/tmp/iscsi_init_session_data.log");
    save_and_upload_log("tar czvf /tmp/iscsi_initconf.tar.gz /etc/iscsi/*", "/tmp/iscsi_initconf.tar.gz");
}

1;
