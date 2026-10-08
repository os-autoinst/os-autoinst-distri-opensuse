# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: library for VT perf testsuites
# Maintainer: James Wang <jnwang@suse.com>

package vt_perf_libs;

use warnings;
use strict;
use Mitigation;
use testapi;
use utils;
use bootloader_setup qw(grub_mkconfig change_grub_config add_grub_cmdline_settings remove_grub_cmdline_settings grep_grub_settings set_framebuffer_resolution set_extrabootparams_grub_conf);
use power_action_utils 'power_action';

=head2 prepare_git_repo

	prepare_git_repo($git_branch_name, $git_repo_url);

Downlaod git repo.
C<$git_branch_name> Branch name in string.
C<$git_repo_url> URL in string.
=cut

sub prepare_git_repo {
    my ($git_branch_name, $git_repo_url) = @_;
    #Prepare mitigations-testsuite.git
    assert_script_run("git config --global http.sslVerify false");
    assert_script_run("rm -rf mitigation-testsuite");
    assert_script_run("git clone -q --single-branch -b $git_branch_name --depth 1 $git_repo_url");
    assert_script_run("pushd mitigation-testsuite");
    assert_script_run("git status");
    assert_script_run("PAGER= git log -1");
}


=head2 switch_to_linux_default_enable

    switch_to_linux_default_enable($self);

Switch to default enable mode of mitigation on linux kernel.
It would be used in Dom0, kvm hypervisor, baremetal.
C<$git_branch_name> Branch name in string.
C<$git_repo_url> URL in string.
=cut

sub switch_to_linux_default_enable {
    my $self = shift;
    my $ret = script_run("grep \"mitigations=off\" /proc/cmdline");
    if ($ret eq 0) {
        #Sometime parameter be writen on the line of GRUB_CMDLINE_LINUX
        assert_script_run("sed -i '/GRUB_CMDLINE_LINUX=/s/mitigations=off/ /g' /etc/default/grub");

        #This remove can't make sure clean all lines.
        remove_grub_cmdline_settings("mitigations=off");

        #reboot make new kernel command-line available
        Mitigation::reboot_and_wait($self, 150);

        #check new kernel command-line
        my $ret = script_run("grep \"mitigations=off\" /proc/cmdline");
        if ($ret eq 0) {
            die 'remove "mitigations=off" from kernel command-line failed';
        }
    }
}



=head2 switch_to_xen_default_enable

    switch_to_linux_default_enable($self);

Switch to default enable mode of mitigation on linux kernel.
It would be used in Dom0, kvm hypervisor, baremetal.
C<$git_branch_name> Branch name in string.
C<$git_repo_url> URL in string.
=cut

sub switch_to_xen_default_enable {
    my $self = shift;
    my $reboot = 0;

    my $ret = script_run("xl info | grep \"xen_commandline\" | grep \"spec-ctrl=off\"");
    if ($ret eq 0) {
        #Sometime parameter be writen on the line of GRUB_CMDLINE_LINUX
        assert_script_run("sed -i '/GRUB_CMDLINE_XEN_DEFAULT=/s/spec-ctrl=off/ /g' /etc/default/grub");

        remove_xen_grub_cmdline_settings("spec-ctrl=off");
        $reboot = 1;

    }
    $ret = script_run("grep \"mitigations=off\" /proc/cmdline");
    if ($ret eq 0) {
        #Sometime parameter be writen on the line of GRUB_CMDLINE_LINUX
        assert_script_run("sed -i '/GRUB_CMDLINE_LINUX=/s/mitigations=off/ /g' /etc/default/grub");

        assert_script_run("sed -i '/GRUB_CMDLINE_LINUX_XEN_REPLACE_DEFAULT=/s/mitigations=off/ /g' /etc/default/grub");

        #This remove can't make sure clean all lines.
        remove_grub_cmdline_settings("mitigations=off");
        $reboot = 1;

    }
    #reboot make new kernel command-line available
    if ($reboot) {
        Mitigation::reboot_and_wait($self, 150);
        #check new kernel command-line
        $ret = script_run("grep \"mitigations=off\" /proc/cmdline");
        if ($ret eq 0) {
            die 'remove "mitigations=off" from kernel command-line failed';
        }
        #check new xen command-line
        $ret = script_run("xl info | grep \"spec-ctrl=off\"");
        if ($ret eq 0) {
            die 'remove "spec-ctrl=off" from xen command-line failed';
        }
    }

}


1;
