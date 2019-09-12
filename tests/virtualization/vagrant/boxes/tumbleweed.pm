# Copyright (C) 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Test for the openSUSE vagrant boxes
# Maintainer: dancermak <dcermak@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use vagrant;
use File::Basename;


sub run() {
    setup_vagrant_libvirt();
    setup_vagrant_virtualbox();

    select_console('root-console');
    zypper_call('in ansible');

    select_console('user-console');

    # version = Tumbleweed, Leap 15 etc
    my $version = get_required_var('VERSION');
    my $arch    = get_required_var('ARCH');
    my $build   = get_required_var('BUILD');

    my %boxes = (
        # openSUSE-Tumbleweed-Vagrant.x86_64-1.0-{libvirt|virtualbox}-Snapshot20190704.vagrant.{libvirt|virtualbox}.box
        libvirt    => "openSUSE-$version-Vagrant.$arch-1.0-libvirt-Snapshot$build.vagrant.libvirt.box",
        virtualbox => "openSUSE-$version-Vagrant.$arch-1.0-virtualbox-Snapshot$build.vagrant.virtualbox.box"
    );

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

    #
    # Grab the remaining test files and bring the boxes up, down and up again
    # be sure to clean them up afterwards
    #
    assert_script_run("wget --quiet " . data_url('virtualization/testfile.txt'));
    assert_script_run("wget --quiet " . data_url('virtualization/provision.sh'));
    assert_script_run("wget --quiet " . data_url('virtualization/ansible_playbook.yml'));

    foreach my $provider (@providers) {
        my $boxname = "$version-$provider";

        # Test the box *only*: bring it up and destroy it immediately afterwards
        assert_script_run("vagrant up $boxname --provider $provider --no-provision", timeout => 1200);

        # now run the actual tests via the Ansible test playbook
        assert_script_run("vagrant provision $boxname", timeout => 1200);

        # test if the box survives a reboot
        assert_script_run("vagrant halt");
        assert_script_run("vagrant up $boxname", timeout => 1200);

        assert_script_run("vagrant destroy -f $boxname");
    }

    # cleanup after all the tests ran
    foreach my $provider (@providers) {
        my $boxname = "$boxes{$provider}";
        assert_script_run("vagrant box remove --force --provider $provider ../$boxname");
        assert_script_run("rm ../$boxname");
    }

    assert_script_run("popd");
}

1;
