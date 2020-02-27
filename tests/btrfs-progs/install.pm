# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
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
    my $cmd  = "[[ -f $file ]] || echo 'Test in progress' > $file";
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
    );
    zypper_call('in ' . join(' ', @deps));
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Install btrfs-progs
    if (get_var('BTRFS_PROGS_REPO')) {
        # Add filesystems repository and install btrfs-progs package
        zypper_call 'rm btrfsprogs';
        zypper_call '--no-gpg-checks ar -f ' . get_var('BTRFS_PROGS_REPO') . ' filesystems';
        zypper_call '--gpg-auto-import-keys ref';
        zypper_call 'in -r filesystems btrfs-progs';
        zypper_call 'rr filesystems';
        assert_script_run 'cd /opt/btrfs-progs-tests';
    }
    else {
        # Build test suite of btrfs-progs from git
        use constant INST_DIR => '/opt/btrfs-progs-tests';
        use constant GIT_URL  => get_var('BTRFS_PROGS_GIT_URL', 'https://github.com/kdave/btrfs-progs.git');
        install_dependencies;
        assert_script_run 'wget ' . autoinst_url('/data/btrfs-progs/install.sh');
        assert_script_run 'chmod a+x install.sh';
        assert_script_run './install.sh ' . GIT_URL . " " . INST_DIR, timeout => 1200;
        assert_script_run 'cd ' . INST_DIR;
    }

    # Create log file
    log_create STATUS_LOG;
}

sub test_flags {
    return {fatal => 1};
}

1;

