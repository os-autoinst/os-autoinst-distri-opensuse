# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
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
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_opensuse is_sle);

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
    push(@deps, 'python310-pyaml') if is_opensuse;
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
      time
    );
    push(@deps, 'python310-pyaml') if is_opensuse;
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
    my $nfsversion = shift;
    assert_script_run('mkdir -p /exportdir && echo \'/exportdir *(rw,no_root_squash,insecure)\' >> /etc/exports');

    my $nfsgrace = get_var('NFS_GRACE_TIME', 90);
    assert_script_run("echo 'options lockd nlm_grace_period=$nfsgrace' >> /etc/modprobe.d/lockd.conf && echo 'options lockd nlm_timeout=5' >> /etc/modprobe.d/lockd.conf");

    if ($nfsversion == '3') {
        assert_script_run("echo 'MOUNT_NFS_V3=\"yes\"' >> /etc/sysconfig/nfs");
        assert_script_run("echo 'MOUNT_NFS_DEFAULT_PROTOCOL=3' >> /etc/sysconfig/autofs && echo 'OPTIONS=\"-O vers=3\"' >> /etc/sysconfig/autofs");
        assert_script_run("echo 'Defaultvers=3' >> /etc/nfsmount.conf && echo 'Nfsvers=3' >> /etc/nfsmount.conf");
    }
    else {
        assert_script_run("sed -i 's/NFSV4LEASETIME=\"\"/NFSV4LEASETIME=\"$nfsgrace\"/' /etc/sysconfig/nfs");
        assert_script_run("echo -e '[nfsd]\\ngrace-time=$nfsgrace\\nlease-time=$nfsgrace' > /etc/nfs.conf.local");
    }
    assert_script_run('systemctl restart rpcbind && systemctl enable nfs-server.service && systemctl restart nfs-server');

    # There's a graceful time we need to wait before using the NFS server
    my $gracetime = script_output('cat /proc/fs/nfsd/nfsv4gracetime;');
    sleep($gracetime * 2);
}

sub run {
    select_serial_terminal;

    # Disable PackageKit
    quit_packagekit;

    install_testsuite;
    setup_nfs_server(get_var("NFSVERSION"));
}

sub test_flags {
    return {fatal => 1};
}

1;
