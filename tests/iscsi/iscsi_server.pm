# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: util-linux lvm2 yast2-iscsi-lio-server targetcli python3-targetcli-fb
# Summary: Test suite for iSCSI server and client
#    Multimachine testsuites, server test creates iscsi target and client test uses it
# - Open xterm, configure server network and create drive for iscsi
# - Verify iscsi connection before setup
# - Start yast2 iscsi server wizard
# - Verify systemd services after configuration
# - Create mutex for child job -> triggers start of initiator configuration
# - Wait for child mutex, initiator is being configured
# - Verify iscsi connections, ACL must be set!
# - Initiator can continue to test iscsi drive
# - Wait idle while initiator finishes its execution
# - Run till client is done
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use lockapi qw(mutex_create mutex_wait);
use version_utils qw(is_sle is_leap);
use mmapi qw(get_children wait_for_children);
use utils qw(zypper_call systemctl type_string_slow_extended);
use yast2_widget_utils 'change_service_configuration';
use scheduler 'get_test_suite_data';
use y2_mm_common 'prepare_xterm_and_setup_static_network';

# load expected test data from yaml
# common for both iscsi MM modules
my $test_data = get_test_suite_data();

sub create_fileio {
    if (defined($test_data->{target_conf}->{backstore})) {
        assert_script_run 'dd if=/dev/zero of=' . $test_data->{target_conf}->{backstore} . ' seek=1M bs=8192 count=1';
    } else {
        die "FileIO path has not been defined!\n";
    }
}

sub create_lvm {
    # get last empty disk
    my $pv = script_output("lsblk -p | awk 'END {print \$1}'");
    if ($pv =~ /\/dev\/vdb/) {
        assert_script_run("pvcreate $pv");
        assert_script_run("vgcreate vg_iscsi $pv");
        assert_script_run("lvcreate -n remote_lv -L 10G vg_iscsi");
    } else {
        die "Missing secondary drive!\n";
    }
}

# install open-iscsi, yast2 modules
# create backstore
# iscsi considers lvm and hdd as iblocks
sub prepare_iscsi_deps {
    zypper_call 'in yast2-iscsi-lio-server targetcli';
    die "No backstore defined in the yaml schedule!\n" unless defined($test_data->{target_conf}->{backstore_type});
    if ($test_data->{target_conf}->{backstore_type} eq 'fileio') {
        create_fileio;
    } elsif ($test_data->{target_conf}->{backstore_type} eq 'lvm') {
        create_lvm;
    } elsif ($test_data->{target_conf}->{backstore_type} eq 'hdd') {
        die "No secondary drive attached to target system!\n"
          if (script_output("lsblk -p | awk 'END {print \$1}'") !~ $test_data->{target_conf}->{backstore});
    } else {
        die "Unknow backstore type -> $test_data->{target_conf}->{backstore_type}\nAllowed values: fileio|hdd|lvm";
    }
}

sub target_service_tab {
    unless (is_sle('<15') || is_leap('<15.1')) {
        if (is_sle('=15')) {
            change_service_configuration(
                after_writing => {start => 'alt-a'},
                after_reboot => {start_on_boot => 'alt-d'}
            );
        } else {
            change_service_configuration(
                after_writing => {start => 'alt-w'},
                after_reboot => {start_on_boot => 'alt-a'}
            );
        }
    }
    # open port in firewall
    send_key 'alt-o';
    assert_screen 'iscsi-target-overview-service-tab';
}

sub config_2way_authentication {
    if (is_sle('=15-SP4')) {
        record_soft_failure('bsc#1191112 - Resizing window as workaround for YaST content not loading');
        send_key_until_needlematch('iscsi-target-modify-acls', 'alt-f10', 10, 2);
    }
    else {
        assert_screen 'iscsi-target-modify-acls';
    }
    send_key 'alt-a';
    assert_screen 'iscsi-target-modify-acls-initiator-popup';
    if (is_sle('>=15')) {
        send_key 'alt-i';
    } else {
        send_key_until_needlematch 'iscsi-client-name-selected', 'tab';
    }
    type_string_slow_extended $test_data->{initiator_conf}->{name} . ':' . $test_data->{initiator_conf}->{id};
    send_key 'alt-o';
    assert_screen 'iscsi-target-modify-acls';
    send_key 'alt-u';
    assert_screen 'iscsi-target-modify-acls-authentication';
    # initiator & target credential fields are swapped in sle12 and sle15
    my %key_shortcuts;
    if (is_sle('>=15')) {
        $key_shortcuts{enable_auth_init} = 'alt-h';
        $key_shortcuts{auth_init_user} = 'alt-m';
        $key_shortcuts{auth_init_pass} = 'alt-t';
        $key_shortcuts{enable_auth_target} = 'alt-e';
        $key_shortcuts{auth_target_user} = 'alt-u';
        $key_shortcuts{auth_target_pass} = 'alt-p';

    } else {
        $key_shortcuts{enable_auth_init} = 'alt-t';
        $key_shortcuts{auth_init_user} = 'alt-s';
        $key_shortcuts{auth_init_pass} = 'alt-a';
        $key_shortcuts{enable_auth_target} = 'alt-h';
        $key_shortcuts{auth_target_user} = 'alt-u';
        $key_shortcuts{auth_target_pass} = 'alt-p';
    }
    $key_shortcuts{enable_auth_target} = 'alt-n' if (is_sle('=15'));
    send_key $key_shortcuts{enable_auth_init};
    assert_screen 'iscsi-target-acl-auth-initiator-enable-auth';
    send_key $key_shortcuts{auth_init_user};
    type_string_slow_extended $test_data->{initiator_conf}->{user};
    assert_screen 'iscsi-target-acl-auth-initiator-username';
    send_key $key_shortcuts{auth_init_pass};
    my $init_pass = reverse $test_data->{common}->{password};
    type_string_slow_extended($init_pass);
    assert_screen 'iscsi-target-acl-auth-initiator-pass' if is_sle('>=15');
    send_key $key_shortcuts{enable_auth_target};
    assert_screen 'iscsi-target-acl-auth-target-enable-auth';
    send_key $key_shortcuts{auth_target_user};
    type_string_slow_extended $test_data->{target_conf}->{user};
    assert_screen 'iscsi-target-acl-auth-target-username';
    send_key $key_shortcuts{auth_target_pass};
    type_string_slow_extended $test_data->{common}->{password};
    assert_screen 'iscsi-target-acl-auth-target-pass' if is_sle('>=15');
    send_key 'alt-o';
    assert_screen 'iscsi-target-modify-acls';
    send_key 'alt-n';
    if (is_sle('>=15')) {
        assert_screen 'iscsi-target-acl-warning';
        send_key 'alt-y';
    }
}

sub target_backstore_tab {
    send_key 'alt-t';    # go to target tab
    assert_screen 'iscsi-target-targets-tab';
    send_key 'alt-a';    # add target
                         # we need to wait while YaST generates Identifier value
    wait_still_screen(stilltime => 1, timeout => 5, similarity_level => 44);
    send_key 'alt-t';    # select target field
    wait_still_screen(stilltime => 1, timeout => 5, similarity_level => 44);
    send_key 'ctrl-a';    # select all text inside target field
    wait_still_screen(stilltime => 1, timeout => 5, similarity_level => 45);
    send_key 'delete';    # text it is automatically selected after tab, delete
    type_string_slow_extended $test_data->{target_conf}->{name};
    send_key 'tab';    # tab to identifier field
    wait_still_screen(stilltime => 1, timeout => 5, similarity_level => 44);
    send_key 'delete';
    type_string_slow_extended $test_data->{target_conf}->{id};
    # un-check bind all IPs
    # explicitly check use authentication only on sle15
    # checked by default in sle12
    if (is_sle('>=15')) {
        wait_still_screen(stilltime => 1, timeout => 5, similarity_level => 45);
        send_key 'alt-l';
        wait_still_screen(stilltime => 1, timeout => 5, similarity_level => 45);
        send_key 'alt-u';
    }
    wait_still_screen(stilltime => 1, timeout => 5, similarity_level => 44);
    send_key 'alt-a';    # add LUN
    assert_and_click('iscsi-target-LUN-path-selected', timeout => 20);
    type_string_slow_extended $test_data->{target_conf}->{backstore};
    assert_screen 'iscsi-target-LUN';
    send_key 'alt-o';    # OK
    assert_screen 'iscsi-target-overview';
    send_key 'alt-n';    # next
    config_2way_authentication;
    assert_screen 'iscsi-target-overview-target-tab';
    send_key 'alt-f';    # finish
    mutex_create('iscsi_ready');    # setup is done client can connect
}

sub display_targets {
    my (%args) = @_;
    my $cmd = 'targetcli sessions list | tee -a ' . "/dev/$serialdev";
    assert_script_run 'targetcli ls';
    # targetcli does not support sessions option in sle12
    return if (is_sle '<15');
    $cmd .= '| grep -i ' . $args{expected} if defined($args{expected}) . ' | tee -a ' . "/dev/$serialdev";
    assert_script_run $cmd;
}

sub run {
    my $self = shift;
    # open xterm, configure server network and create drive for iscsi
    prepare_xterm_and_setup_static_network(ip => $test_data->{target_conf}->{ip}, message => 'Configure MM network - server');
    prepare_iscsi_deps;
    # verify iscsi connection before setup
    record_info 'iSCSI Sessions', 'Display target sessions & settings before iscsi configuration';
    display_targets(expected => qq('no open sessions'));
    # start yast2 wizard
    record_info 'iSCSI target', 'Start target configuration';
    my $module_name = y2_module_guitest::launch_yast2_module_x11('iscsi-lio-server', target_match => 'iscsi-lio-server');
    target_service_tab;
    target_backstore_tab;
    wait_serial("$module_name-0", 180) || die "'yast2 iscsi-lio-server' didn't finish or exited with non-zero code";
    # verify systemd services after configuration
    record_info 'Systemd - after', 'Verify status of iscsi services and sockets';
    my $service = (is_sle('>=15') ? 'targetcli.service' : 'target.service');
    systemctl("is-active $service");
    # create mutex for child job -> triggers start of initiator configuration
    # setup is done client can connect
    mutex_create('iscsi_target_ready');
    my $children = get_children();
    my $child_id = (keys %$children)[0];
    # wait for child mutex, initiator is being configured
    mutex_wait("iscsi_initiator_ready", $child_id, 'Initiator configuration in progress!');
    # verify iscsi connections, ACL must be set!
    record_info 'iSCSI Sessions', 'Display target sessions & settings after setup';
    display_targets(expected => 'LOGGED_IN');
    # initiator can continue to test iscsi drive
    mutex_create('iscsi_display_sessions');
    # wait idle while initiator finishes its execution
    wait_for_children;
    enter_cmd "killall xterm";
    # run till client is done
    wait_for_children;
    $self->result('ok');
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook;
    my $target_label = $test_data->{target_conf}->{name} . '\\:' . $test_data->{target_conf}->{id};
    my $initiator_label = $test_data->{initiator_conf}->{name} . '\\:' . $test_data->{initiator_conf}->{id};
    display_targets;
    unless (script_run('ls -la /sys/kernel/config/iscsi')) {
        # show amount of normal logouts
        script_run 'cat /sys/kernel/config/target/iscsi/' . $target_label . '/fabric_statistics/iscsi_logout_stats/normal_logouts';
        # show amount of abnormal logouts
        script_run 'cat /sys/kernel/config/target/iscsi/' . $target_label . '/fabric_statistics/iscsi_logout_stats/abnormal_logouts';
        # show amount of active sessions
        script_run 'cat /sys/kernel/config/target/iscsi/' . $target_label . '/fabric_statistics/iscsi_instance/sessions';
        # show ACL information
        script_run 'cat /sys/kernel/config/target/iscsi/' . $target_label . '/tpgt_1/acls/' . $initiator_label . '/info';
        # show auth credentials and configuration
        script_run 'cat /sys/kernel/config/target/iscsi/' . $target_label . '/tpgt_1/acls/' . $initiator_label . '/tpgt_1/auth/*';
        # show auth credentials and acls configuration
        script_run 'cat /sys/kernel/config/target/iscsi/' . $target_label . '/tpgt_1/acls/' . $initiator_label . '/tpgt_1/acls/auth/*';
    }
}

1;
