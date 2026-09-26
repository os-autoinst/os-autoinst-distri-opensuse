# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Set up a kernel build tree from a kernel.org shallow-clone tarball.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use Kernel::utils 'get_verified_shallow_tar';

sub run {
    select_serial_terminal;
    install_package('curl coreutils git-core gpg2 tar', trup_apply => 1);
    script_run('rm -rf ./linux');
    get_verified_shallow_tar(
        tree => get_var('KERNEL_GIT_TREE'),
        branch => get_var('KERNEL_GIT_BRANCH'),
        commit => get_var('KERNEL_GIT_COMMIT'),
    );
}

1;
