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

# Summary: Test for vagrant and packaged addons
# Maintainer: dancermak <dcermak@suse.com>

use strict;
use warnings;
use base "basetest";
use testapi;
use utils;

sub run_vagrant_virtualbox(){
    record_info('INFO', 'Vagrant Virtualbox');

    select_console('root-console');

    zypper_call('in vagrant virtualbox');
    assert_script_run('systemctl start vboxdrv');
    assert_script_run('systemctl start vboxautostart');
    assert_script_run('usermod -a -G vboxusers bernhard');

    select_console('user-console');
    assert_script_run('echo "test" > testfile');

    assert_script_run('vagrant init ubuntu/xenial64');
    assert_script_run('vagrant up --provider virtualbox', timeout => 1200);

    assert_script_run('vagrant ssh -c "[ $(cat testfile) = \"test\" ]"');
    assert_script_run('vagrant halt');
    assert_script_run('vagrant destroy -f');
}

sub run_vagrant_libvirt(){
    record_info('INFO', 'Vagrant libvirt');
    my $arch = get_var('ARCH');
    my $Vagrantfile_content;

    select_console('root-console');

    assert_script_run('mkdir vagrant_libvirt/ && pushd vagrant_libvirt/');

    zypper_call('in vagrant libvirt-devel gcc make patch ruby-devel zlib-devel');
    assert_script_run('systemctl start libvirtd');

    select_console('user-console');
    assert_script_run('echo "test" > testfile');

    assert_script_run('vagrant plugin install vagrant-libvirt', timeout => 700);

    # Image depends on architecture
    if ("$arch" eq 'aarch64') {
      assert_script_run('curl -LO https://download.opensuse.org/repositories/home:/Guillaume_G:/branches:/Virtualization:/Appliances:/Images:/openSUSE-Tumbleweed/openSUSE_Tumbleweed_ARM/openSUSE-Tumbleweed-Vagrant.aarch64-libvirt.box');
      assert_script_run('vagrant box add openSUSE-Tumbleweed-Vagrant.aarch64-libvirt.box --name TW_libvirt');
      $Vagrantfile_content = 'Vagrant.configure("2") do |config| \
  config.vm.box = "ignisf/debian8-arm" \
  config.vm.base_mac = "00163E22EAB9" \
 \
  config.vm.provider :libvirt do |libvirt| \
    libvirt.driver = "kvm" \
    libvirt.loader = "/usr/share/qemu/aavmf-aarch64-code.bin" \
    libvirt.machine_type = "aarch64" \
    # Specify the default hypervisor features \
    libvirt.features = ["apic"] \
    libvirt.cpu_mode = "host-passthrough" \
    libvirt.video_type = "vga" \
    # Additionnal flags \
    libvirt.host =\'localhost\' \
    libvirt.uri =\'qemu:///system\' \
    libvirt.memory = \'1024\' \
    libvirt.cpus = \'1\' \
    libvirt.storage_pool_name = \'default\' \
    libvirt.host = "master" \ \
    libvirt.nvram = "" \
    libvirt.machine_type = "virt-3.1" \
    libvirt.emulator_path = "/usr/bin/qemu-system-aarch64" \
  end \
end';
    }
    elsif ("$arch" eq 'x86_64') {
      assert_script_run('curl -LO https://download.opensuse.org/tumbleweed/appliances/openSUSE-Tumbleweed-Vagrant.x86_64-libvirt.box');
      assert_script_run('vagrant box add openSUSE-Tumbleweed-Vagrant.x86_64-libvirt.box --name TW_libvirt');
    } else {
      die "$arch is not supported";
    }
#     assert_script_run('vagrant init TW_libvirt');
    assert_script_run("echo $Vagrantfile_content > Vagrantfile") if $Vagrantfile_content;
    assert_script_run('cat Vagrantfile');
    assert_script_run('vagrant up --provider libvirt', timeout => 1200);
    assert_script_run('vagrant ssh -c "[ $(cat /vagrant/testfile) = \"test\" ]"');
    assert_script_run('vagrant halt');
    assert_script_run('vagrant destroy');

    assert_script_run('popd');
}

sub run() {
    run_vagrant_virtualbox() if check_var('ARCH', 'x86_64');
    run_vagrant_libvirt()    if get_var('ARCH') =~ /aarch64|x86_64/;
}

1;
