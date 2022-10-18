# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemd-container
# Summary: Test systemd-nspawn "chroots", booting systemd and starting from OCI bundle
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Architectures;
use utils;
use version_utils;
use strict;
use warnings;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    zypper_call 'in systemd-container';

    record_info 'setup';
    if (script_run("test -d /var/lib/machines/") != 0) {
        record_info('workaround', "/var/lib/machines/ wasn't created by systemd-container RPM\nCreating it now.");
        assert_script_run("mkdir -p /var/lib/machines/");
    }
    my $pkg_repo = get_var('MIRROR_HTTP', 'dvd:/?devices=/dev/sr0');
    my $release_pkg = (is_sle) ? 'sles-release' : 'openSUSE-release';
    my $packages = "systemd shadow zypper $release_pkg";
    my $machine = "test1";
    my $path = "/var/lib/machines/$machine";
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
    assert_script_run "systemd-nspawn -M $machine date";
    assert_script_run "systemd-nspawn -M $machine sh -c 'echo foobar | tee /foo.txt'";
    assert_script_run "grep foobar $path/foo.txt";
    assert_script_run "rm $path/foo.txt";
    assert_script_run "systemd-nspawn -M $machine --bind /dev/shm sh -c 'echo foobar | tee /dev/shm/foo.txt'";
    assert_script_run "grep foobar /dev/shm/foo.txt";
    assert_script_run "rm /dev/shm/foo.txt";

    record_info 'boot';
    systemctl 'start systemd-nspawn@' . $machine;
    systemctl 'status systemd-nspawn@' . $machine;
    # Wait for container to boot
    script_retry "systemd-run -tM $machine /bin/bash -c date", retry => 30, delay => 5;
    script_retry "journalctl -n10 -M $machine | grep 'Reached target Multi-User System'", retry => 30, delay => 5;
    validate_script_output "systemd-run -tM $machine /bin/bash -c 'systemctl status'", qr/systemd-logind/;
    systemctl 'stop systemd-nspawn@' . $machine;
    script_retry 'systemctl status systemd-nspawn@' . $machine, retry => 30, delay => 5, expect => 3;

    record_info 'machinectl';
    validate_script_output "machinectl list-images", qr/$machine/;
    assert_script_run "machinectl start test1";
    # Wait for container to boot
    script_retry "systemd-run -tM $machine /bin/bash -c date", retry => 30, delay => 5;
    script_retry "journalctl -n10 -M $machine | grep 'Reached target Multi-User System'", retry => 30, delay => 5;
    validate_script_output "machinectl list", qr/$machine/;
    assert_script_run "machinectl shell $machine /bin/echo foobar | grep foobar";
    assert_script_run 'machinectl shell messagebus@' . $machine . ' /usr/bin/whoami | grep messagebus';
    # on backend svirt-xen-hvm we have problem with systemd-journald and it requires a restart before checking status
    assert_script_run "machinectl shell $machine /usr/bin/systemctl restart systemd-journald";
    assert_script_run "machinectl shell $machine /usr/bin/systemctl status systemd-journald | grep -B100 -A100 'active (running)'";
    assert_script_run "machinectl stop test1";
    script_retry 'systemctl status systemd-nspawn@' . $machine, retry => 30, delay => 5, expect => 3;
    assert_script_run "rm -rf $path";


    record_info 'oci bundle';
    assert_script_run 'cd /tmp/';
    assert_script_run 'wget -O oci_testbundle.tgz ' . data_url('oci_testbundle.tgz');
    assert_script_run 'tar xf oci_testbundle.tgz';
    assert_script_run 'ls -l oci_testbundle';
    if (!is_x86_64) {
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
