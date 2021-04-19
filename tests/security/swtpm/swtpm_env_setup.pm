# Copyright (C) 2021 SUSE LLC
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
#
# Summary: Ship the "swtpm" software TPM emulator for QEMU,
#          install required packages and download the pre-installed
#          OS images for later tests, prepare a script for remote
#          ssh login and execution
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#81256, tc#1768671

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Install the required packages for libvirt environment setup,
    # "expect" is used for later remote login test, so install here as well
    zypper_call("in qemu libvirt swtpm expect virt-install virt-manager");

    # Start libvirtd daemon and start the default libvirt network
    assert_script_run("systemctl start libvirtd");
    assert_script_run("virsh net-start default");
    assert_script_run("systemctl is-active libvirtd");
    assert_script_run("virsh net-list | grep default | grep active");

    # Download the pre-installed guest images and sample xml files
    my $image_path   = '/var/lib/libvirt/images';
    my $legacy_image = 'swtpm_legacy@64bit.qcow2';
    my $uefi_image   = 'swtpm_uefi@64bit.qcow2';
    if (get_var('HDD_SWTPM_LEGACY')) {
        my $hdd_swtpm_legacy = get_required_var('HDD_SWTPM_LEGACY');
        assert_script_run("wget -c -P $image_path " . autoinst_url("/assets/hdd/$hdd_swtpm_legacy"), 900);
        assert_script_run("mv $image_path/$hdd_swtpm_legacy $image_path/$legacy_image");
        assert_script_run("wget --quiet " . data_url("swtpm/swtpm_legacy.xml") . " -P $image_path");
    }
    elsif (get_var('HDD_SWTPM_UEFI')) {
        my $hdd_swtpm_uefi = get_required_var('HDD_SWTPM_UEFI');
        assert_script_run("wget -c -P $image_path " . autoinst_url("/assets/hdd/$hdd_swtpm_uefi"), 900);
        assert_script_run("mv $image_path/$hdd_swtpm_uefi $image_path/$uefi_image");
        assert_script_run("wget --quiet " . data_url("swtpm/swtpm_uefi.xml") . " -P $image_path");
    }

    # Write expect script to implement ssh access into remote host and run some commands
    assert_script_run("wget --quiet " . data_url("swtpm/ssh_script") . " -P $image_path");

    # Change permission of the expect script
    assert_script_run("chmod 755 $image_path/ssh_script");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
