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
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_transactional is_sle_micro);
use transactional;
use Utils::Architectures 'is_aarch64';

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
    if (get_var('BTRFS_PROGS_DEPS')) { @deps = split(/ /, get_var('BTRFS_PROGS_DEPS')); }
    zypper_call('in ' . join(' ', @deps));
}

sub run {
    select_serial_terminal;

    # Install btrfs-progs from zypper
    if (my $repo_url = get_var('BTRFS_PROGS_REPO')) {
        my $btrfs_package_name = get_var('KEEP_DEFAULT_BTRFS_BINARY') ? 'btrfs-progs-tests' : 'btrfs-progs';
        my $dep_url = get_var('DEPENDENCY_REPO', 'http://download.suse.de/ibs/home:/yosun:/branches:/SUSE:/Factory:/Head/standard/');
        zypper_ar($repo_url, name => 'btrfs-progs-repo', priority => 90);
        zypper_ar($dep_url, name => 'dependency-repo', priority => 90);
        if (is_transactional) {
            trup_call("pkg install $btrfs_package_name");
            (is_sle_micro(">=6.0") && is_aarch64) ? process_reboot(trigger => 1, expected_grub => 0) : reboot_on_changes;
        }
        else {
            zypper_call 'rm btrfsprogs' unless get_var('KEEP_DEFAULT_BTRFS_BINARY');
            zypper_call "in $btrfs_package_name";
        }
        set_var('WORK_DIR', '/opt/btrfs-progs-tests');
        record_info('repo info', script_output('zypper lr -dE'));
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

