# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Install btrfs-progs
# Maintainer: An Long <lan@suse.com>
use strict;
use warnings;
use base 'opensusebasetest';
use utils;
use testapi;

use constant STATUS_LOG => '/opt/status.log';

# Create log file used to generate junit xml report
sub log_create {
    my $file = shift;
    my $cmd = "[[ -f $file ]] || echo 'Test in progress' > $file";
    assert_script_run($cmd);
}

sub install_dependencies {
    my @deps = qw(
      autoconf
      automake
      lzo-devel
      git-core
      gcc
      libblkid-devel
      zlib-devel
      libext2fs-devel
      libmount-devel
      libuuid-devel
    );
    if (get_var('BTRFS_PROGS_DEPS')) {
        @deps = split(/,/, get_var('BTRFS_PROGS_DEPS'));
    }
    zypper_call('in ' . join(' ', @deps));
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Install btrfs-progs
    if (get_var('BTRFS_PROGS_REPO')) {
        # Add filesystems repository and install btrfs-progs package
        my $btrfs_package_name;
        if (get_var('KEEP_DEFAULT_BTRFS_BINARY')) {
            $btrfs_package_name = get_var('BTRFS_PACKAGE_NAME', 'btrfs-progs-tests');
        }
        else {
            $btrfs_package_name = get_var('BTRFS_PACKAGE_NAME', 'btrfs-progs');
            zypper_call 'rm btrfsprogs';
        }
        zypper_call '--no-gpg-checks ar -f ' . get_var('BTRFS_PROGS_REPO') . ' filesystems';
        zypper_call '--gpg-auto-import-keys ref -r filesystems';
        zypper_call "in -r filesystems $btrfs_package_name";
        zypper_call 'rr filesystems';
        set_var('WORK_DIR', '/opt/btrfs-progs-tests');
    }
    else {
        # Build test suite of btrfs-progs from git
        use constant INST_DIR => '/opt/btrfs-progs-tests';
        use constant GIT_URL => get_var('BTRFS_PROGS_GIT_URL', 'https://github.com/kdave/btrfs-progs.git');
        my $keep_default_btrfs_binary;
        if (get_var('KEEP_DEFAULT_BTRFS_BINARY')) {
            $keep_default_btrfs_binary = 1;
        }
        else {
            $keep_default_btrfs_binary = 0;
        }
        install_dependencies;
        assert_script_run 'wget ' . autoinst_url('/data/btrfs-progs/install.sh');
        assert_script_run 'chmod a+x install.sh';
        assert_script_run './install.sh ' . GIT_URL . " " . INST_DIR . " " . $keep_default_btrfs_binary, timeout => 1200;
        set_var('WORK_DIR', INST_DIR);
    }

    # Create log file
    log_create STATUS_LOG;
}

sub test_flags {
    return {fatal => 1};
}

1;

