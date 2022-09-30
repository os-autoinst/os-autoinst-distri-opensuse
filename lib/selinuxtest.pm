# SUSE's openQA tests
#
# Copyright 2020-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Base module for SELinux test cases
# Maintainer: QE Security <none@suse.de>

package selinuxtest;

use strict;
use warnings;
use testapi;
use utils;
use Utils::Backends 'is_pvm';
use bootloader_setup qw(add_grub_cmdline_settings replace_grub_cmdline_settings);
use power_action_utils 'power_action';

use base "opensusebasetest";

our @EXPORT = qw(
  $file_contexts_local
  $file_output
  $policyfile_tar
  download_policy_pkgs
);

our $file_contexts_local = '/etc/selinux/minimum/contexts/files/file_contexts.local';
our $file_output = '/tmp/cmd_output';
our $policypkg_repo = get_var('SELINUX_POLICY_PKGS');
our $policyfile_tar = 'testing-master';
our $dir = '/tmp/';

# download SELinux policy pkgs
sub download_policy_pkgs {
    # download SELinux 'policy' pkgs
    assert_script_run("wget --no-check-certificate $policypkg_repo -O ${dir}${policyfile_tar}.tar");
    assert_script_run("tar -xvf ${dir}${policyfile_tar}.tar -C ${dir}");
}

# creat a test dir/file
sub create_test_file {
    my ($self, $test_dir, $test_file) = @_;

    assert_script_run("rm -rf $test_dir");
    assert_script_run("mkdir -p $test_dir");
    assert_script_run("touch ${test_dir}/${test_file}");
}

# run `fixfiles restore` and check the fcontext before and after
sub fixfiles_restore {
    my ($self, $file_name, $fcontext_pre, $fcontext_post) = @_;

    if (script_run("[ -z $file_name ]") == 0) {
        record_info("WARNING", "no file need to be restored", result => "softfail");
    }
    elsif (script_run("[ -f $file_name ]") == 0) {
        validate_script_output("ls -Z $file_name", sub { m/$fcontext_pre/ });
        assert_script_run("fixfiles restore $file_name");
        validate_script_output("ls -Z $file_name", sub { m/$fcontext_post/ });
    }
    elsif (script_run("[ -d $file_name ]") == 0) {
        validate_script_output("ls -Zd $file_name", sub { m/$fcontext_pre/ });
        assert_script_run("fixfiles restore $file_name");
        validate_script_output("ls -Zd $file_name", sub { m/$fcontext_post/ });
    }
}

# check SELinux contexts of a file/dir
sub check_fcontext {
    my ($self, $file_name, $fcontext) = @_;

    if (script_run("[ -f $file_name ]") == 0) {
        validate_script_output("ls -Z $file_name", sub { m/.*_u:.*_r:$fcontext:s0\ .*$file_name$/ });
    }
    elsif (script_run("[ -d $file_name ]") == 0) {
        validate_script_output("ls -Zd $file_name", sub { m/.*_u:.*_r:$fcontext:s0\ .*$file_name$/ });
    }
    else {
        record_info("WARNING", "file \"$file_name\" is abnormal", result => "softfail");
        assert_script_run("ls -lZd $file_name");
    }
}

# check SELinux security category of a file/dir
sub check_category {
    my ($self, $file_name, $category) = @_;

    if (script_run("[ -f $file_name ]") == 0) {
        validate_script_output("ls -Z $file_name", sub { m/.*_u:.*_r:.*_t:$category\ .*$file_name$/ });
    }
    elsif (script_run("[ -d $file_name ]") == 0) {
        validate_script_output("ls -Zd $file_name", sub { m/.*_u:.*_r:.*_t:$category\ .*$file_name$/ });
    }
    else {
        record_info("WARNING", "file \"$file_name\" is abnormal", result => "softfail");
        assert_script_run("ls -lZd $file_name");
    }
}

sub reboot_and_reconnect {
    my ($self, %args) = @_;
    power_action('reboot', textmode => $args{textmode});
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(textmode => $args{textmode}, ready_time => 600, bootloader_time => 300);
}

sub set_sestatus {
    my ($self, $mode, $type) = @_;
    my $selinux_config_file = '/etc/selinux/config';
    $self->select_serial_terminal;

    # workaround for 'selinux-auto-relabel' in case: auto relabel then trigger reboot
    my $results = script_run("zypper --non-interactive se selinux-autorelabel");
    if (!$results) {
        assert_script_run("sed -ie \'s/GRUB_TIMEOUT.*/GRUB_TIMEOUT=8/\' /etc/default/grub");
    }

    # enable SELinux in grub
    die "Need mode 'enforcing' or 'permissive'" unless $mode =~ /enforcing|permissive/;
    replace_grub_cmdline_settings('lsm=apparmor', '', update_grub => 1);
    add_grub_cmdline_settings('lsm=selinux security=selinux selinux=1 enforcing=' . ($mode eq 'enforcing' ? 1 : 0), update_grub => 1);

    # control (enable) the status of SELinux on the system, e.g., "enforcing" or "permissive"
    assert_script_run("sed -i -e 's/^SELINUX=/#SELINUX=/' $selinux_config_file");
    assert_script_run("echo SELINUX=$mode >> $selinux_config_file");

    # set SELINUXTYPE, e.g., 'minimum' or 'targeted'
    assert_script_run("sed -i -e 's/^SELINUXTYPE=/#SELINUXTYPE=/' $selinux_config_file");
    assert_script_run("echo SELINUXTYPE=$type >> $selinux_config_file");
    assert_script_run('systemctl enable auditd');

    # reboot the vm and reconnect the console
    $self->reboot_and_reconnect(textmode => 1);
    $self->select_serial_terminal;

    validate_script_output(
        'sestatus',
        sub {
            m/
            SELinux\ status:\ .*enabled.*
            SELinuxfs\ mount:\ .*\/sys\/fs\/selinux.*
            SELinux\ root\ directory:\ .*\/etc\/selinux.*
            Loaded\ policy\ name:\ .*$type.*
            Current\ mode:\ .*$mode.*
            Mode\ from\ config\ file:\ .*$mode.*
            Policy\ MLS\ status:\ .*enabled.*
            Policy\ deny_unknown\ status:\ .*allowed.*
            Max\ kernel\ policy\ version:\ .*[0-9]+.*/sx
        });
}

1;
