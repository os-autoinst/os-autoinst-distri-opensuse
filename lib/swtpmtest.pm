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
  collect_swtpm_diagnostics
);

my $image_path = '/var/lib/libvirt/images';
my $diag_dir = '/var/log/swtpm';
# Serial log lives under libvirt's own qemu log dir so it inherits the
# AppArmor/SELinux rules that already let qemu write there. Putting it
# under $diag_dir trips MAC denial even with chmod 666 (poo#200561).
my $serial_dir = '/var/log/libvirt/qemu';
# Name of the most recently started swtpm guest. swtpm_verify() only
# receives the swtpm version, not the vm type (uefi/legacy), so it relies
# on start_swtpm_vm() having stored the active vm_name here.
my $active_vm_name;

# Log host-side context up front so the test details page shows the
# pieces we always end up asking for first when a swtpm run goes red:
# package versions, OVMF firmware presence, SELinux mode. Failok — this
# is informational.
sub _record_swtpm_preflight {
    my $ovmf_pkg = is_aarch64 ? 'qemu-uefi-aarch64' : 'qemu-ovmf-x86_64';
    my $pkgs = script_output(
        "rpm -q qemu swtpm libtpms0 libvirt-daemon $ovmf_pkg || true",
        proceed_on_failure => 1
    );
    record_info('swtpm pkgs', $pkgs);

    my $fw_glob = is_aarch64 ? '/usr/share/qemu/*aarch64*' : '/usr/share/qemu/ovmf-x86_64*';
    my $fw = script_output(
        "ls -la $fw_glob 2>&1; sha256sum ${fw_glob}-code* ${fw_glob}-vars* 2>&1 || true",
        proceed_on_failure => 1
    );
    record_info('OVMF firmware', $fw);

    my $sel = script_output("getenforce 2>&1; sestatus 2>&1 || true", proceed_on_failure => 1);
    record_info('SELinux', $sel);
}

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

    # Redirect the guest's serial console from a pty to a file on the host
    # so we can post-mortem boot/network failures (poo#200561). Without
    # this, a guest that hangs in OVMF or before bringing up virtio-net
    # leaves no trace anywhere in the openQA artifacts.
    my $serial_log = "$serial_dir/${vm_name}-serial.log";
    my $serial_target_type = is_aarch64 ? 'system-serial' : 'isa-serial';
    my $serial_model_name = is_aarch64 ? 'pl011' : 'isa-serial';
    assert_script_run("mkdir -p $diag_dir $serial_dir && :> $serial_log && chown qemu:qemu $serial_log");
    assert_script_run(
        "perl -i -0pe '"
          . "s{<serial type=.pty.>.*?</serial>}{<serial type=\"file\"><source path=\"$serial_log\" append=\"on\"/><target type=\"$serial_target_type\" port=\"0\"><model name=\"$serial_model_name\"/></target></serial>}s;"
          . "s{<console type=.pty.>.*?</console>}{<console type=\"file\"><source path=\"$serial_log\" append=\"on\"/><target type=\"serial\" port=\"0\"/></console>}s"
          . "' $guest_xml->{$swtpm_vm_type}"
    );

    # The XML pins the strict MS-keyed OVMF (ovmf-x86_64-ms-4m-code.bin),
    # whose enrolled db trusts only SUSE production-signed kernels.
    # Engineering kernels (e.g. 6.12.0-999999_stage.1-default from
    # Online-Updates-Staging) are signed with the SUSE engineering cert
    # and get rejected by shim ("bad shim signature") -> guest never
    # boots, sshd never comes up, the SSH probe in swtpm_verify gives up.
    # The SUT and the nested-guest qcow2 are built from the same staging
    # snapshot, so the SUT's own kernel is a reliable proxy for what's
    # inside the nested disk. On engineering kernels, swap the loader to
    # the plain UEFI variant: no enrolled keys, no SB enforcement, shim
    # becomes transparent. swtpm/TPM PCR measurements still happen, so
    # the test's assertions are unaffected. Production-kernel runs keep
    # the original strict loader, so the SB path stays exercised there.
    if ($swtpm_vm_type eq 'uefi' && !is_aarch64) {
        my $kver = script_output('uname -r');
        my $plain = '/usr/share/qemu/ovmf-x86_64-4m-code.bin';
        if ($kver =~ /(_stage\.\d+|999999)/ && script_run("test -f $plain") == 0) {
            assert_script_run(
                "sed -i 's|ovmf-x86_64-ms-4m-code\\.bin|ovmf-x86_64-4m-code.bin|' "
                  . $guest_xml->{$swtpm_vm_type}
            );
            record_info('OVMF', "engineering kernel ($kver) -> swapped nested loader to $plain (SB off)");
        }
    }

    _record_swtpm_preflight();

    # Define the guest vm and start it
    assert_script_run("virsh define $guest_xml->{$swtpm_vm_type}");
    assert_script_run("virsh start $vm_name");
    $active_vm_name = $vm_name;
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

# Function "collect_swtpm_diagnostics" snapshots everything we need to
# diagnose a nested-guest boot or networking hang and uploads it as openQA
# artifacts. Safe to call on success or failure; every step is failok so
# collection itself never masks the real failure.
sub collect_swtpm_diagnostics {
    my ($vm_name) = @_;
    return unless $vm_name;

    my $bundle = "$diag_dir/${vm_name}-diag";
    script_run("mkdir -p $bundle");

    # Guest serial console (only present if start_swtpm_vm rewired the XML).
    # This is the primary signal: full boot trace from OVMF → kernel → systemd.
    script_run("cp -a $serial_dir/${vm_name}-serial.log $bundle/ 2>/dev/null");

    # Libvirt's own per-domain log: qemu stderr/stdout, chardev errors,
    # OVMF/firmware messages, swtpm chardev wiring.
    script_run("cp -a /var/log/libvirt/qemu/${vm_name}.log $bundle/ 2>/dev/null");
    script_run("cp -a /var/log/libvirt/swtpm/libvirt/qemu/${vm_name}-swtpm.log $bundle/ 2>/dev/null");

    # Single point-of-failure screenshot — useful when the hang is in a
    # graphical-only stage (OVMF setup screen, GRUB menu) the serial log
    # can't see.
    script_run("virsh screenshot $vm_name $bundle/screenshot.ppm 2>&1");

    # Live device + cpu state from qemu's monitor. info tpm is the key
    # one for ruling in/out a swtpm hand-off problem.
    for my $hmp (
        'info status', 'info registers', 'info pci',
        'info network', 'info tpm', 'info qtree',
        'info chardev', 'info usernet'
      )
    {
        (my $slug = $hmp) =~ s/\s+/-/g;
        script_run("virsh qemu-monitor-command $vm_name --hmp '$hmp' > $bundle/qmp-$slug.txt 2>&1");
    }

    # Materialised state at the moment of failure.
    script_run("virsh dumpxml $vm_name > $bundle/dumpxml.txt 2>&1");
    script_run("virsh domstate --reason $vm_name > $bundle/domstate.txt 2>&1");
    script_run("virsh domiflist $vm_name > $bundle/domiflist.txt 2>&1");
    script_run("virsh net-dhcp-leases default > $bundle/net-dhcp-leases.txt 2>&1");
    script_run("virsh net-dumpxml default > $bundle/net-default.xml 2>&1");
    script_run("(ip -d link show; ip addr; ip route; bridge fdb show; bridge link show) > $bundle/host-net.txt 2>&1");
    script_run("ls -laZ /run/libvirt/qemu/swtpm/ > $bundle/swtpm-sockets.txt 2>&1");
    script_run("ss -lx | grep -i swtpm > $bundle/swtpm-listen.txt 2>&1");
    script_run("ps -ef | grep -E 'qemu|swtpm' | grep -v grep > $bundle/processes.txt 2>&1");
    script_run("ausearch -m AVC -ts recent 2>&1 | tail -n 200 > $bundle/audit-avc.txt 2>&1");
    script_run("journalctl -b --no-pager | tail -n 500 > $bundle/journal-tail.txt 2>&1");

    script_run("tar -C $diag_dir -czf /tmp/${vm_name}-diag.tar.gz ${vm_name}-diag");
    upload_logs("/tmp/${vm_name}-diag.tar.gz", failok => 1);
}

# Function "swtpm_verify" logs into the VM to run commands for checking
# tpm parameters along with required information
sub swtpm_verify {
    my $para = shift;
    die "invalid swtpm parameter $para" unless ($guestvm_cfg->{$para});
    record_info("Current SWTPM device version is: ", "$para");

    # Check the vm guest is up via listening to the port 22. Pass die => 0
    # so we get the return code instead of an exception, collect diagnostics
    # on failure, then die ourselves — guarantees artifacts upload before
    # always_rollback wipes the host state.
    assert_script_run("wget --quiet " . data_url("swtpm/ssh_port_chk_script") . " -P $image_path");
    my $rc = script_retry("bash $image_path/ssh_port_chk_script", retry => 20, die => 0);
    record_info('swtpm diag', 'Collecting nested-guest diagnostics in case of failing');
    collect_swtpm_diagnostics($active_vm_name);
    die 'Could not SSH into the nested VM.' unless $rc == 0;

    # Generate an SSH key and copy it into the VM
    my $leases = script_output('virsh net-dhcp-leases default');
    my ($ip_addr) = $leases =~ /ipv4\s+([\d.]+)\//;
    die 'Could not find an IPv4 address in virsh leases' unless $ip_addr;
    assert_script_run('ssh-keygen -t rsa -b 4096 -f sshkey -N ""');
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
