# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Base module for swtpm test cases
# Maintainer: QE Security <none@suse.de>
# Tags: poo#81256, tc#1768671, poo#102849, poo#108386, poo#100512

package swtpmtest;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';
use Utils::Architectures;

our @EXPORT = qw(
  start_swtpm_vm
  stop_swtpm_vm
  swtpm_verify
);

my $image_path = '/var/lib/libvirt/images';
my $guestvm_cfg = {
    swtpm_1 => {
        xml_file => {uefi => 'swtpm_uefi_1_2.xml', legacy => 'swtpm_legacy_1_2.xml'},
        version => '1.2',
    },
    swtpm_2 => {
        xml_file => {uefi => 'swtpm_uefi_2_0.xml', legacy => 'swtpm_legacy_2_0.xml'},
        version => '2.0',
    },
};

my $sample_cfg = {
    uefi => {vm_name => 'vm-swtpm-uefi', sample_file => 'swtpm_uefi'},
    legacy => {vm_name => 'vm-swtpm-legacy', sample_file => 'swtpm_legacy'},
};

# Function "start_swtpm_vm" starts a vm via libvirt "virsh" commands
# sample xml file and vm image file are pre-configured
sub start_swtpm_vm {
    my ($swtpm_ver, $swtpm_vm_type) = @_;
    die "invalid swtpm type parameter $swtpm_ver" unless ($guestvm_cfg->{$swtpm_ver});
    die "invalid vm type parameter $swtpm_vm_type" unless ($sample_cfg->{$swtpm_vm_type});

    # Copy the sample configuration file and modify it based on the test requirement
    my $guest_swtpm_ver = $guestvm_cfg->{$swtpm_ver};
    my $guest_mode = $sample_cfg->{$swtpm_vm_type};
    my $vm_name = $guest_mode->{vm_name};
    my $sample_xml = $guest_mode->{sample_file};
    my $guest_xml = $guest_swtpm_ver->{xml_file};
    my $swtpm_type = $guest_swtpm_ver->{version};
    $sample_xml .= is_aarch64 ? '_aarch64.xml' : '.xml';
    assert_script_run("cd $image_path");
    assert_script_run("cp $sample_xml $guest_xml->{$swtpm_vm_type}");
    assert_script_run(
"sed -i \"/<\\/devices>/i\\    <tpm model='tpm-tis'>\\n      <backend type='emulator' version='$swtpm_type'\\/>\\n    <\\/tpm>\" $guest_xml->{$swtpm_vm_type}"
    );

    # Define the guest vm and start it
    assert_script_run("virsh define $guest_xml->{$swtpm_vm_type}");
    assert_script_run("virsh start $vm_name");
}

# Function "stop_swtpm_vm" stops/destroys a running vm
sub stop_swtpm_vm {
    my $para = shift;
    die "invalid vm type parameter $para" unless ($sample_cfg->{$para});

    # For UEFI vm guest, we should add --nvram option
    my $guest_mode = $sample_cfg->{$para};
    my $vm_name = $guest_mode->{vm_name};
    my $undef_vm_cmd = "virsh undefine $vm_name";
    $undef_vm_cmd .= ' --nvram' if $para eq 'uefi';
    assert_script_run("virsh destroy $vm_name");
    assert_script_run("$undef_vm_cmd");
}

# Function "swtpm_verify" logs into the VM to run commands for checking
# tpm parameters along with required information
sub swtpm_verify {
    my $para = shift;
    die "invalid swtpm parameter $para" unless ($guestvm_cfg->{$para});
    record_info("Current SWTPM device version is: ", "$para");

    # Check the vm guest is up via listening to the port 22
    assert_script_run("wget --quiet " . data_url("swtpm/ssh_port_chk_script") . " -P $image_path");
    assert_script_run("bash $image_path/ssh_port_chk_script", timeout => 200);

    # Generate an SSH key and copy it into the VM
    my $ip_addr = script_output("ip n | awk '/192\\.168\\.122/ {print \$1}'");
    assert_script_run('ssh-keygen -f sshkey -N ""');
    enter_cmd("ssh-copy-id -i sshkey.pub -o 'StrictHostKeyChecking no' ${ip_addr}");
    wait_serial(qr/assword:/);
    enter_cmd($testapi::password);

    # Login to the vm and run the commands to check tpm device
    my $ssh_prefix = "ssh -i sshkey ${ip_addr}";
    assert_script_run("$ssh_prefix stat /dev/tpm0");

    if ($para eq "swtpm_1") {
        validate_script_output("$ssh_prefix tpm_version", qr/TPM 1.2 Version/);
    }
    elsif ($para eq "swtpm_2") {
        assert_script_run("$ssh_prefix stat /dev/tpmrm0");
        validate_script_output("$ssh_prefix tpm2_pcrread sha256:0", qr/0 :/);
    }

    my $eventlog = script_output("$ssh_prefix tpm2_eventlog /sys/kernel/security/tpm0/binary_bios_measurements");

    # Due to bsc#1199864, the following works only on SLE >= 15-SP4
    if (!is_sle('<15-SP4')) {
        # Measured boot check
        # If measured boot works fine, it can record available algorithms and pcrs
        die "Missing parts in the event log" unless $eventlog =~ /AlgorithmId|pcrs/;
    }

    assert_script_run('rm sshkey sshkey.pub');
}

1;
