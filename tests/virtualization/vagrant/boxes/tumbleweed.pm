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
    my $is_virtualbox_applicable = is_x86_64();

    setup_vagrant_libvirt();
    setup_vagrant_virtualbox() if $is_virtualbox_applicable;

    select_console('root-console');
    zypper_call('in ansible');

    select_console('user-console');

    # version = Tumbleweed, Leap 15 etc
    my $version = get_required_var('VERSION');
    my $arch = get_required_var('ARCH');
    my $arch_ext;
    $arch_ext = "_$arch" if !is_x86_64();
    my $build = get_required_var('BUILD');

    my %boxes = (
        # Tumbleweed.x86_64-1.0-{libvirt|virtualbox}-Snapshot20190704.vagrant.{libvirt|virtualbox}.box
        libvirt => "$version.$arch-1.0-libvirt$arch_ext-Snapshot$build.vagrant.libvirt.box",
    );
    # virtualbox is supported only on x86_64
    %boxes = (%boxes, virtualbox => "$version.$arch-1.0-virtualbox-Snapshot$build.vagrant.virtualbox.box") if $is_virtualbox_applicable;

    my @providers = keys %boxes;

    #
    # get Vagrantfile template and replace the distro name & insert box filenames
    #
    assert_script_run("wget --quiet " . data_url("virtualization/Vagrantfile"));
    assert_script_run("sed -i 's|DISTRO|$version|' Vagrantfile");

    foreach my $provider (@providers) {
        my $boxname = "$boxes{$provider}";
        assert_script_run("wget --quiet " . autoinst_url("/assets/other/$boxname"));

        my $upcase_provider = uc $provider;
        assert_script_run("sed -i 's|BOXNAME_$upcase_provider|$boxname|' Vagrantfile");
    }

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

    foreach my $provider (@providers) {
        run_test_per_provider($version, $provider);
    }
    assert_script_run("export BOX_STATIC_IP=1");
    foreach my $provider (@providers) {
        run_test_per_provider($version, $provider);
    }

    # cleanup after all the tests ran
    foreach my $provider (@providers) {
        my $boxname = "$boxes{$provider}";
        run_vagrant_cmd("box remove --force --provider $provider ../$boxname");
        assert_script_run("rm ../$boxname");
    }

    assert_script_run("popd");
}

1;
