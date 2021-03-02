# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: systemd-container
# Summary: Test systemd-nspawn "chroots", booting systemd and starting from OCI bundle
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'opensusebasetest';
use testapi;
use utils;
use version_utils;
use strict;
use warnings;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    zypper_call 'in systemd-container';

    record_info 'setup';
    if (script_run("test -d /var/lib/machines/") != 0) {
        record_info('workaround', "/var/lib/machines/ wasn't created by systemd-container RPM\nCreating it now.");
        assert_script_run("mkdir -p /var/lib/machines/");
    }
    my $pkg_repo    = get_var('MIRROR_HTTP', 'dvd:/?devices=/dev/sr0');
    my $release_pkg = (is_sle) ? 'sles-release' : 'openSUSE-release';
    my $packages    = "systemd shadow zypper $release_pkg";
    my $machine     = "test1";
    my $path        = "/var/lib/machines/$machine";
    if (is_sle) {
        $pkg_repo =~ s/Online/Full/;    # only the full image contains the required pkgs
        my $rel_repo = $pkg_repo . '/Product-SLES/';
        $pkg_repo = $pkg_repo . '/Module-Basesystem/';
        zypper_call("--root $path --gpg-auto-import-keys addrepo $rel_repo relrepo");
    }
    zypper_call("--root $path --gpg-auto-import-keys addrepo $pkg_repo defaultrepo");
    zypper_call("--root $path --gpg-auto-import-keys refresh");
    zypper_call("--root $path install --no-recommends -ly $packages", exitcode => [0, 107]);

    record_info 'chroot';
    type_string "systemd-nspawn -M $machine --bind /dev/$serialdev\n";
    assert_script_run "date";
    assert_script_run "echo foobar | tee /foo.txt";
    type_string "exit\n";
    assert_script_run "grep foobar $path/foo.txt";
    assert_script_run "rm $path/foo.txt";

    record_info 'boot';
    systemctl 'start systemd-nspawn@' . $machine;
    systemctl 'status systemd-nspawn@' . $machine;
    # Wait for container to boot
    script_retry "systemd-run -tM $machine /bin/bash -c date", retry => 30, delay => 5;
    assert_script_run "systemd-run -tM $machine /bin/bash -c 'systemctl status' | grep -A1 test1 | grep State: | grep running";
    systemctl 'stop systemd-nspawn@' . $machine;

    record_info 'machinectl';
    assert_script_run "machinectl list-images | grep -B1 -A2 test1";
    assert_script_run "machinectl start test1";
    # Wait for container to boot
    script_retry "systemd-run -tM $machine /bin/bash -c date", retry => 30, delay => 5;
    assert_script_run "machinectl list | grep -B1 -A2 test1";
    assert_script_run "machinectl shell $machine /bin/echo foobar | grep foobar";
    assert_script_run 'machinectl shell messagebus@' . $machine . ' /usr/bin/whoami | grep messagebus';
    assert_script_run "machinectl shell $machine /usr/bin/systemctl status systemd-journald | grep -B100 -A100 'active (running)'";
    assert_script_run "machinectl stop test1";
    script_retry 'systemctl status systemd-nspawn@' . $machine, retry => 30, delay => 5, expect => 3;
    validate_script_output 'journalctl -n10 -u systemd-nspawn@' . $machine, sub { m/Reached target Power-Off/ };
    assert_script_run "rm -rf $path";


    record_info 'oci bundle';
    assert_script_run 'cd /tmp/';
    assert_script_run 'wget -O oci_testbundle.tgz ' . data_url('oci_testbundle.tgz');
    assert_script_run 'tar xf oci_testbundle.tgz';
    assert_script_run 'ls -l oci_testbundle';
    if (!check_var('ARCH', 'x86_64')) {
        # our bundle is x86_64 but is essentially only busybox
        # so we'll simply replace the binary with one of the right arch
        zypper_call 'in busybox-static';
        assert_script_run 'cp -v /usr/bin/busybox-static ./oci_testbundle/rootfs/bin/busybox';
    }
    if (script_run('(systemd-nspawn --oci-bundle=/tmp/oci_testbundle || true) |& grep "Failed to resolve path rootfs"') == 0) {
        record_soft_failure 'bsc#1182598 - Loading rootfs from OCI bundle not according to specification';
        assert_script_run 'cd oci_testbundle';
    }
    assert_script_run 'systemd-nspawn --oci-bundle=/tmp/oci_testbundle | grep "Hello World"';
    assert_script_run 'cd';
}

1;
