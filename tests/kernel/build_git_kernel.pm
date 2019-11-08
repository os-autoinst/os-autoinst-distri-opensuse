# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: build, install and boot a custom, upstream kernel tree
#          from an arbitrary git tree
#
# Maintainer: Michael Moese <mmoese@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'power_action';

sub run {
    my $self       = shift;
    my $git_tree   = get_required_var('KERNEL_GIT_TREE');
    my $git_branch = get_var('KERNEL_GIT_BRANCH', 'master');

    $self->select_serial_terminal;

    # download, compile and install a kernel tree from git
    zypper_call('in git-core ncurses-devel gcc flex bison libelf-devel libopenssl-devel');
    # git clone takes a long time due to slow network connection
    assert_script_run("git clone --depth 1 --single-branch --branch $git_branch $git_tree linux", 7200);

    assert_script_run('cd linux');
    assert_script_run('zcat /proc/config.gz > .config');
    assert_script_run('make olddefconfig');
    assert_script_run('yes | make localmodconfig');

    # building a kernel takes a while, give it a long timeout in case we run
    # this on a slower machine
    assert_script_run('make -j `nproc` | tee /tmp/kernelbuild.log', 3600);
    assert_script_run("sed -i 's/allow_unsupported_modules 0/allow_unsupported_modules 1/g' /etc/modprobe.d/10-unsupported-modules.conf");
    assert_script_run('make install modules_install');
    assert_script_run('mkinitrd -f iscsi,md,multipath,lvm,lvm2,ifup,fcoe,dcbd');

    power_action('reboot', textmode => 1, keepconsole => 1);

    # make sure we wait until the reboot is done
    select_console('sol', await_console => 0);
    assert_screen('linux-login', 1800);
}

sub post_fail_hook {
    my $self = @_;
    upload_logs('/tmp/kernelbuild.log');
}

1;
