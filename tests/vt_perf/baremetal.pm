# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: VT perf testsuite on Baremetal testing
# Maintainer: James Wang <jnwang@suse.com>

package baremetal;

use warnings;
use strict;
use base "opensusebasetest";
use Mitigation;
use vt_perf_libs;
use Utils::Backends 'use_ssh_serial_console';
use bootloader_setup qw(grub_mkconfig change_grub_config add_grub_cmdline_settings remove_grub_cmdline_settings grep_grub_settings set_framebuffer_resolution set_extrabootparams_grub_conf);
use ipmi_backend_utils;
use power_action_utils 'power_action';
use testapi;
use utils;

my $syspath         = '/sys/devices/system/cpu/vulnerabilities/';
my $git_repo_url    = get_required_var("MITIGATION_GIT_REPO");
my $git_user        = get_required_var("MITIGATION_GIT_REPO_USER");
my $git_pass        = get_required_var("MITIGATION_GIT_REPO_PASS");
my $git_branch_name = get_required_var("MITIGATION_GIT_BRANCH_NAME");
my $deploy_script   = get_required_var("DEPLOY_SCRIPT");
my $run_id          = get_required_var("RUN_ID");


sub run {
    my $self = shift;
    #Prepare mitigations-testsuite.git
    vt_perf_libs::prepare_git_repo($git_branch_name, $git_repo_url);

    #deploy script might be return not 0. use script_run.
    #we ignore exit code now. testing result will be checked later.
    script_run("sh deploy_scripts/${deploy_script}");

    #Prepare config and list file.
    assert_script_run("sed \'/SQ_ABUILD_PARTITION/d\' io-test-list >~/qaset/list");
    assert_script_run("echo _QASET_RUNID=${run_id} >~/qaset/config");
    assert_script_run("echo NPB_CLASS_SET=\"C\" >>~/qaset/config");

    #check kernel if set mitigations=off.
    #If yes, we set to default mode: mitigations=auto.
    vt_perf_libs::switch_to_linux_default_enable($self);

    #Start testing.
    #We might be reboot from a grub2 update. Re-enter directory.
    assert_script_run("pushd ~/mitigation-testsuite");

    assert_script_run("sh ./qaset_run.sh");
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
}

1;
