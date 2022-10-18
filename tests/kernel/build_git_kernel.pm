# SUSE's openQA tests
#
# Copyright 2019-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: git-core ncurses-devel gcc flex bison libelf-devel libopenssl-devel
# make dracut
# Summary: build, install and boot a custom, upstream kernel tree
#          from an arbitrary git tree
#
# Maintainer: Michael Moese <mmoese@suse.de>, Yiannis Bonatakis <ybonatakis@suse.com>

use Mojo::Base qw(opensusebasetest);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use power_action_utils 'power_action';

sub run {
    my $self = shift;
    my $git_tree = get_required_var('KERNEL_GIT_TREE');
    my $git_branch = get_var('KERNEL_GIT_BRANCH', 'master');

    select_serial_terminal;

    # download, compile and install a kernel tree from git
    zypper_call('in bc git-core ncurses-devel gcc flex bison libelf-devel libopenssl-devel');
    # git clone takes a long time due to slow network connection
    assert_script_run("git clone --depth 1 --single-branch --branch $git_branch $git_tree linux", 7200);
    assert_script_run('cd linux');
    assert_script_run('zcat /proc/config.gz > .config');

    assert_script_run("sed -i 's/CONFIG_MODULE_SIG_KEY=.*/CONFIG_MODULE_SIG_KEY=\"\"/' .config");
    assert_script_run("sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYRING=.*/CONFIG_SYSTEM_TRUSTED_KEYRING=n/' .config");
    assert_script_run("sed -i 's/CONFIG_DEBUG_INFO_BTF=y/# CONFIG_DEBUG_INFO_BTF=y/' .config");

    assert_script_run('make olddefconfig');
    assert_script_run('make -j `nproc` 2>&1 | tee /tmp/kernelbuild.log', 3600);
    assert_script_run("sed -i 's/allow_unsupported_modules 0/allow_unsupported_modules 1/g' /lib/modprobe.d/10-unsupported-modules.conf");
    assert_script_run('make modules_install', 3600);
    assert_script_run('make install');

    assert_script_run('mkinitrd /boot/initrd-$(make kernelrelease) $(make kernelrelease)');
    assert_script_run('cp /boot/vmlinuz /boot/vmlinuz-$(make kernelrelease)');
    assert_script_run('ls -la /boot | grep vmlinuz-$(make kernelrelease)');
    assert_script_run('update-bootloader');

    record_info 'curr kernel', script_output 'uname -r';

    power_action('reboot', textmode => 1, keepconsole => 1);
    reconnect_mgmt_console();
    $self->wait_boot_past_bootloader;
}

sub post_fail_hook {
    my $self = @_;
    upload_logs('/tmp/kernelbuild.log');
}

1;
