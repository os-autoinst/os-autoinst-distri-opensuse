# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: vagrant vagrant-libvirt ansible
# Summary: Test for the openSUSE vagrant boxes
# Maintainer: dancermak <dcermak@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use vagrant;
use File::Basename;
use Utils::Architectures;

sub run_test_per_provider {
    my ($version, $provider) = @_;
    my $boxname = "$version-$provider";

    # Test the box *only*: bring it up and destroy it immediately afterwards
    run_vagrant_cmd("up $boxname --provider $provider", timeout => 1200);

    # test if the box survives a reboot
    run_vagrant_cmd('halt', timeout => 120);
    run_vagrant_cmd("up $boxname", timeout => 1200);

    run_vagrant_cmd("destroy -f $boxname", timeout => 120);
}

sub run() {
    setup_vagrant_virtualbox();

    select_console('root-console');
    zypper_call('in ansible');

    select_console('user-console');

    # version = Tumbleweed, Leap 15 etc
    my $version = get_required_var('VERSION');
    my $arch = get_required_var('ARCH');
    my $arch_ext;
    $arch_ext = "_$arch" if !is_x86_64();
    my $build = get_required_var('BUILD');

    # Tumbleweed.x86_64-1.0-{libvirt|virtualbox}-Snapshot20190704.vagrant.{libvirt|virtualbox}.box
    my $box = "$version.$arch-1.0-virtualbox-Snapshot$build.vagrant.virtualbox.box";

    #
    # get Vagrantfile template and replace the distro name & insert box filenames
    #
    assert_script_run("wget --quiet " . data_url("virtualization/Vagrantfile"));
    assert_script_run("sed -i 's|DISTRO|$version|' Vagrantfile");

    assert_script_run("wget --quiet " . autoinst_url("/assets/other/$box"));

    assert_script_run("sed -i 's|BOXNAME_VIRTUALBOX|$box|' Vagrantfile");

    # move the Vagrantfile into a empty subdirectory and invoke vagrant from
    # there, so that we don't synchronize the huge .box files into the VM
    assert_script_run("mkdir test_dir");
    assert_script_run("mv Vagrantfile test_dir/");
    assert_script_run("pushd test_dir");

    # Grab the remaining test files and bring the boxes up, down and up again
    # be sure to clean them up afterwards
    foreach ("testfile.txt", "prepare_repos.sh", "check_ip.sh", "ansible_playbook.yml") {
        assert_script_run("wget --quiet " . data_url("virtualization/$_"));
    }

    run_test_per_provider($version, "virtualbox");

    assert_script_run("export BOX_STATIC_IP=1");
    run_test_per_provider($version, "virtualbox");

    # cleanup after all the tests ran
    run_vagrant_cmd("box remove --force ../$box");
    assert_script_run("rm ../$box");

    assert_script_run("popd");
}

sub post_fail_hook() {
    my ($self) = @_;

    upload_logs($vagrant_logfile);
    $self->SUPER::post_fail_hook;
}

1;
