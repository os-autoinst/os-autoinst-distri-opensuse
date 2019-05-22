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
package install;

use strict;
use warnings;
use base 'opensusebasetest';
use utils;
use testapi;

my $STATUS_LOG = '/opt/status.log';
my $git_url    = get_var('BTRFS_PROGS_GIT_URL', 'https://github.com/kdave/btrfs-progs.git');

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
      python3-devel
      lzo-devel
      git-core
      gcc
      libblkid-devel
      zlib-devel
    );
    zypper_call('in ' . join(' ', @deps));
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Install btrfs-progs
    install_dependencies;
    assert_script_run("git clone -q --depth 1 $git_url", timeout => 360);
    assert_script_run 'cd btrfs-progs';
    assert_script_run './autogen.sh';
    assert_script_run './configure --disable-documentation --disable-convert --disable-zstd';
    assert_script_run 'make', timeout => 1200;
    assert_script_run 'cd tests';

    # Create log file
    log_create($STATUS_LOG);
}

sub test_flags {
    return {fatal => 1};
}

1;

