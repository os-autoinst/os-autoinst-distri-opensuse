# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Prepare system for Workload Memory Protection basic test
# Maintainer: QE-SAP <qe-sap@suse.de>, Alvaro Carvajal <acarvajal@suse.de>

use base "sles4sap";
use testapi;
use utils qw(zypper_call);
use Utils::Systemd qw(systemctl);
use version_utils qw(is_sle);
use bootloader_setup qw(add_grub_cmdline_settings);
use hacluster qw(get_hostname);
use strict;
use warnings;

sub run {
    my ($self) = @_;

    # WMP is a feature of SLES for SAP Applications 15+. Skip test in older systems
    if (is_sle('<15')) {
        record_info 'WMP', 'WMP is only available in SLES for SAP Applications 15+';
        return;
    }

    # Install sapwmp package
    zypper_call 'in sapwmp';

    # Create slice cgroup
    my $systemd_path = '/etc/systemd/system';
    my $sap_slice_cfg = 'SAP.slice';
    assert_script_run "curl -f -v " . autoinst_url . "/data/sles4sap/$sap_slice_cfg -o $systemd_path/$sap_slice_cfg";
    assert_script_run "cat $systemd_path/$sap_slice_cfg";
    systemctl('daemon-reload');

    # Add cgroup capture program to startup profile
    my $sid = get_required_var('INSTANCE_SID');
    my $instance_id = get_required_var('INSTANCE_ID');
    my $instance_type = get_var('INSTANCE_TYPE', 'HDB');
    my $hostname = get_hostname;
    my $profile = "/usr/sap/${sid}/SYS/profile/${sid}_${instance_type}${instance_id}_${hostname}";
    assert_script_run 'echo "# all programs spawned below will be put in dedicated cgroup" >> ' . $profile;
    assert_script_run 'echo "Execute_20 = local /usr/lib/sapwmp/sapwmp-capture -a" >> ' . $profile;
    assert_script_run "tail $profile";

    # Setup cgroup kernel parameter, reboot and verify system boots with parameter configured
    add_grub_cmdline_settings('systemd.unified_cgroup_hierarchy=1', update_grub => 1);
    $self->reboot;
    my $out = script_output 'cat /proc/cmdline';
    die 'Failed to boot with systemd.unified_cgroup_hierarchy set' unless ($out =~ /systemd\.unified_cgroup_hierarchy\=1/);

    # Start & test HANA installation
    $self->set_sap_info($sid, $instance_id);
    $self->set_ps_cmd(get_required_var('INSTANCE_TYPE'));
    $self->user_change;
    $self->test_start;
    $self->reset_user_change;

    # Check sap.slice
    assert_script_run $sles4sap::systemd_cgls_cmd;
}

sub test_flags {
    return {milestone => 1};
}

1;
