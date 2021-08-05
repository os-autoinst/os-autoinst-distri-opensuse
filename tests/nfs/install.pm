# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Install pynfs/cthon04 testsuite
# Maintainer: Yong Sun <yosun@suse.com>
package install;

use 5.018;
use strict;
use warnings;
use base 'opensusebasetest';
use utils;
use testapi;

sub install_dependencies_pynfs {
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

sub install_dependencies_cthon04 {
    my @deps = qw(
      git
      gcc
      make
      patch
      nfs-client
      nfs-kernel-server
      libtirpc-devel
    );
    zypper_call('in ' . join(' ', @deps));
}

sub install_testsuite {
    my $testsuite = shift;
    if (get_var("PYNFS")) {
        my $url = get_var('PYNFS_GIT_URL', 'git://git.linux-nfs.org/projects/bfields/pynfs.git');
        my $rel = get_var('PYNFS_RELEASE');

        $rel = "-b $rel" if ($rel);

        install_dependencies_pynfs;
        assert_script_run("git clone -q --depth 1 $url $rel && cd ./pynfs");
        assert_script_run('./setup.py build && ./setup.py build_ext --inplace');
    }
    elsif (get_var("CTHON04")) {
        my $url = get_var('CTHON04_GIT_URL', 'git://git.linux-nfs.org/projects/steved/cthon04.git');
        install_dependencies_cthon04;
        assert_script_run("git clone -q --depth 1 $url && cd ./cthon04");
        assert_script_run('make');
    }
    record_info('git version', script_output('git log -1 --pretty=format:"git-%h" | tee'));
}

sub setup_nfs_server {
    assert_script_run('mkdir -p /exportdir && echo \'/exportdir *(rw,no_root_squash,insecure)\' >> /etc/exports');
    assert_script_run('echo "NFSD_V4_GRACE=15" >> /etc/sysconfig/nfs && echo "NFSD_V4_LEASE=15" >> /etc/sysconfig/nfs');
    assert_script_run('echo "options lockd nlm_grace_period=15" >> /etc/modprobe.d/lockd.conf && echo "options lockd nlm_timeout=5" >> /etc/modprobe.d/lockd.conf');
    assert_script_run('systemctl enable nfs-server.service && systemctl restart nfs-server');
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Disable PackageKit
    quit_packagekit;

    install_testsuite;
    setup_nfs_server;
}

1;
