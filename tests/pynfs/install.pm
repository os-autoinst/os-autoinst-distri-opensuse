# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Install pynfs
# Maintainer: Yong Sun <yosun@suse.com>
package install;

use 5.018;
use strict;
use warnings;
use base 'opensusebasetest';
use utils;
use testapi;

sub install_dependencies {
    my @deps = qw(
      git
      krb5-devel
      python3-devel
      swig
      python3-gssapi
      python3-ply
      nfs-client
      nfs-kernel-server
    );
    zypper_call('in ' . join(' ', @deps));
}

sub install_pynfs {
    install_dependencies;
    assert_script_run('git clone -q --depth 1 git://git.linux-nfs.org/projects/bfields/pynfs.git && cd ./pynfs');
    record_info('pynfs git version', script_output('git log -1 --pretty=format:"git-%h" | tee'));
    assert_script_run('./setup.py build && ./setup.py build_ext --inplace');
}

sub setup_nfs_server {
    assert_script_run('mkdir -p /exportdir && echo \'/exportdir *(rw,no_root_squash,insecure)\' >/etc/exports && systemctl restart nfs-server');
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Disable PackageKit
    quit_packagekit;

    install_pynfs;
    setup_nfs_server;
}

1;
