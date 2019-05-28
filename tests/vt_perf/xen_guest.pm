# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# This is testsuite run on XEN dom0. Makes sure testsuite could run properly.
# The following example is Dell machine(They usually use com2 as serial device);
# Please add the following parameters into XEN command-line.
# console=com2
#
# Please add the following parameters into Dom0 command-line.
# console=hvc0 console=ttyS0
#
# Please modify grub serial command:
# GRUB_SERIAL_COMMAND="serial --unit=1 --speed=115200 --parity=no --word=8"


# Summary: VT perf testsuite on XEN PV/HVM Guest testing
# Maintainer: James Wang <jnwang@suse.com>

use warnings;
use strict;
use base "opensusebasetest";
use Utils::Backends 'use_ssh_serial_console';
use bootloader_setup qw(grub_mkconfig change_grub_config add_grub_cmdline_settings remove_grub_cmdline_settings grep_grub_settings set_framebuffer_resolution set_extrabootparams_grub_conf);
use Mitigation;
use ipmi_backend_utils;
use power_action_utils 'power_action';
use testapi;
use utils;
use vt_perf_libs;


my $syspath         = '/sys/devices/system/cpu/vulnerabilities/';
my $git_repo_url    = get_required_var("MITIGATION_GIT_REPO");
my $git_user        = get_required_var("MITIGATION_GIT_REPO_USER");
my $git_pass        = get_required_var("MITIGATION_GIT_REPO_PASS");
my $git_branch_name = get_required_var("MITIGATION_GIT_BRANCH_NAME");
my $deploy_script   = get_required_var("DEPLOY_SCRIPT");
my $password        = get_required_var("GUEST_PASSWORD");
my $run_id          = get_required_var("RUN_ID");
my $xen_guest_type  = get_var("XEN_GUEST_TYPE", 'pv');

sub run {
    my $self = shift;

    assert_script_run("test -e /proc/xen", fail_message => 'Current system is not a xen hypervisor dom0');

    #Prepare mitigations-testsuite.git
    vt_perf_libs::prepare_git_repo($git_branch_name, $git_repo_url);

    #ucode update is disable by default on XEN
    my $ret = script_run("xl info | grep \"xen_commandline\" | grep \"ucode=scan\"");
    if ($ret) {
        add_grub_xen_cmdline_settings("ucode=scan");
    }
    $ret = script_run("xl info | grep \"xen_commandline\" | grep \"dom0_max_vcpus=8 dom0_mem=8G,max:8G\"");
    if ($ret) {
        add_grub_xen_cmdline_settings("dom0_max_vcpus=8 dom0_mem=8G,max:8G");
    }

    #check if XEN Hypervisor set spec-ctrl=off and dom5's kernel set mitigations=off
    #If yes, we set to default mode.
    vt_perf_libs::switch_to_xen_default_enable($self);

    assert_script_run("pushd ~/mitigation-testsuite");
    if ($xen_guest_type eq 'hvm') {
        assert_script_run("sed -i 's#vm_type=.*#vm_type=hvm#g' test.config");
    }
    assert_script_run("password=${password} sh main.sh", timeout => 3600);

}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
}

1;
