# SUSE's openQA tests
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: A test to pass an NVIDIA vGPU to guest via libvirt. Only KVM hosts are supported.
# Test environment: one AMPERE GPU card, such A10, A30 etc., with SR-IOV capability and/or MIG features in host machine;
#                   A UEFI guest vm is defined in the host, and they are ssh accessible from host.
# Test flow:
#    - install the NVIDIA vGPU manager on host and reboot
#    - create a GPU Instance and a Compute Instance if MIG feature is available
#    - create a vGPU device in host
#    - assign the vGPU device to guest vm
#    - install the vGPU driver in guest vm
#    - detach vGPU from guest and remove the vGPU
# Maintainer: qe-virt@suse.de, Julie CAO <JCao@suse.com>

use base "virt_feature_test_base";
use strict;
use warnings;
use utils;
use testapi;
use virt_autotest::common;
use version_utils qw(is_sle);
use virt_autotest::utils;
use Utils::Backends qw(use_ssh_serial_console is_remote_backend);
use ipmi_backend_utils qw(reconnect_when_ssh_console_broken);

our $log_dir = "/tmp/vgpu";
our $vm_xml_save_dir = "/tmp/download_vm_xml";

sub run_test {
    my $self = shift;

    # Use sol & ssh console explixitly in case test module run on an installed host
    # thus no login_console.pm has been required any more
    select_console 'sol', await_console => 0;
    use_ssh_serial_console;

    # Test Prerequisite is fulfilled
    return unless is_host_ready_for_vgpu_test();

    my $gpu_device = get_gpu_device();
    die "No NVIDIA AMPERE GPU card on the machine!" if $gpu_device eq '';

    # Clean up test logs
    script_run "[ -d $log_dir ] && rm -rf $log_dir; mkdir -p $log_dir";

    # Install NVIDIA vGPU manager
    my $vgpu_manager = get_required_var("VGPU_MANAGER_URL");
    install_vgpu_manager_and_reboot($vgpu_manager);

    # Enable SR-IOV VFs
    enable_sriov($gpu_device);

    return if check_var('VGPU_TEST', 'short');

    # Create a Compute Instance(CI) for GPU with MIG mode supported, such A30/A100
    # given MIG mode is enabled. will handle non MIG mode when zen2 is available
    if (get_var('GPU_MIG_MODE')) {
        enable_mig_mode();
        # Create a GI(GPU Instance)
        my ($gi_id, $gpu_id) = create_gpu_instance();
        # Create a CI(Compute Instance)
        my $ci_id = create_compute_instance($gi_id, $gpu_id);
    }

    # Create a vGPU device
    my $vgpu = create_vgpu($gpu_device, get_var('GPU_MIG_MODE'));

    save_original_guest_xmls();
    my $vgpu_grid_driver = get_required_var("VGPU_GRID_DRIVER_URL");
    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info("Guest $guest");

        # Configure the guest
        prepare_guest_for_vgpu_passthrough($guest);

        # Assign vGPU to guest
        my $gpu_slot_in_guest = "0x0a";
        assign_vgpu_to_guest($vgpu, $guest, $gpu_slot_in_guest);

        # Install vGPU grid driver in guest
        install_vgpu_grid_driver($guest, $vgpu_grid_driver);

        # Detach vGPU from guest
        detach_vgpu_from_guest($gpu_slot_in_guest, $guest);
        check_guest_health($guest);
    }

    # Remove vGPU device
    remove_vgpu($vgpu);

    # Disable GPU SR-IOV
    assert_script_run("/usr/lib/nvidia/sriov-manage -d $gpu_device");
    record_info("SRIOV disabled", $gpu_device);

    # Upload vgpu related logs
    upload_virt_logs($log_dir, "logs");

    # Redefine guest from their original configuration files
    restore_original_guests();
}

sub is_host_ready_for_vgpu_test {
    if (is_sle('<15-SP3') or !is_kvm_host) {
        record_info("Host not supported!", "NVIDIA vGPU is only supported on KVM hosts with SLE15SP3 and greater!", result => 'softfail');
        return 0;
    }
    #check VT-d is supported in Intel x86_64 machines
    if (script_run("grep -m 1 Intel /proc/cpuinfo") == 0) {
        assert_script_run "dmesg | grep -E \"DMAR:.*IOMMU enabled\"";
    }
    script_run("lsmod | grep -e vfio -e nvidia -e mdev");
    return 1;
}

sub get_gpu_device {
    #NVIDIA AMPERE GPU
    my $gpu_devices = script_output("lspci | grep NVIDIA | cut -d ' ' -f1");
    foreach (split("\n", $gpu_devices)) {
        return $_ if script_run("lspci -v -s $_ | grep 'SR-IOV'") == 0;
    }
}

sub install_vgpu_manager_and_reboot {
    my ${dirver_url} = shift;
    die "The vGPU driver URL requires to be in 'http://...' format!" unless ${dirver_url} =~ /http:\/\/.*\/(.*\.run)/;
    my ${driver_file} = $1;

    # Check if vGPU manager has been already loaded
    if (script_run("nvidia-smi") == 0) {
        my ${driver_version} = script_output("nvidia-smi -q | grep 'Driver Version' | grep -oE \"[0-9.]+\"");
        if (${driver_file} =~ /${driver_version}/) {
            record_info("Warning", "vGPU manager ${driver_version} has already been loaded!", result => 'softfail');
            return;
        }
    }

    # Remove NVIDIA open driver (refer to bsc#1239449)
    zypper_call "rm nvidia-open-driver-*" if script_run("rpm -qa | grep nvidia-open-driver") == 0;
    script_run("rpm -aq | grep nvidia");

    # Install vGPU manager
    download_script(${driver_file}, script_url => ${dirver_url});
    zypper_call "in kernel-default-devel gcc";
    assert_script_run("modprobe vfio_pci_core") if is_sle('=15-SP5');
    assert_script_run("./${driver_file} -s");
    record_info("vGPU manager is installed successfully.");

    # Reboot host(it took 180+ seconds for ph052 to bootup with calltrace)
    enter_cmd("grub2-once 0; reboot");
    record_info("Host rebooting ...");
    wait_for_host_reboot;
    check_host_health;

    # Verify vGPU manager installed successfully
    assert_script_run("lspci -d 10de: -k");
    assert_script_run("lsmod | grep nvidia");
    assert_script_run("nvidia-smi");
    script_run("ls -ld /sys/class/m*");
}

sub enable_sriov {
    my $gpu = shift;
    assert_script_run("/usr/lib/nvidia/sriov-manage -e $gpu");
    # It takes a few seconds
    sleep 3;
    script_run("dmesg | tail");
    assert_script_run("ls -l /sys/bus/pci/devices/0000:$gpu/ | grep virtfn");
    assert_script_run("lspci | grep NVIDIA");
    record_info("SR-IOV enabled");
}

sub enable_mig_mode {
    # Enable MIG mode
    assert_script_run("nvidia-smi -mig 1");
    # Verify MIG mode is enabled
    assert_script_run("nvidia-smi -i 0 --query-gpu=pci.bus_id,mig.mode.current --format=csv | grep 'Enabled'");
    record_info("Mig Mode is enalbed!");
}

sub create_gpu_instance {

    # Create a GI by randomly picking up a supported type which has free instances by the GPU device model
    # Only those profiles on which there are available instances are candidates
    script_run("nvidia-smi mig -lgip");
    my $avail_gi_profile_cmd = "nvidia-smi mig -lgip | grep MIG | grep -v '0/' | grep -v '+me'";
    die "No available GI profiles!" unless script_run($avail_gi_profile_cmd) == 0;
    my @gi_profile_ids = split '\n', script_output("$avail_gi_profile_cmd | awk '{ print \$5 }'");
    my $gi_profile = $gi_profile_ids[int(rand($#gi_profile_ids + 1))];
    my ($gi_id, $gpu_id);
    if (script_output("nvidia-smi mig -cgi $gi_profile") =~ /Successfully created GPU instance ID\s+(\d*) on GPU\s+(\d*)/) {
        ($gi_id, $gpu_id) = ($1, $2);
        assert_script_run("nvidia-smi mig -lgi");
    }
    else {
        die "Fail to create a GPU Instance!";
    }
    record_info("GI created", "GPU_ID: \$gpu_id, GI_ID: \$gi_id");

    return ($gi_id, $gpu_id);
}

sub create_compute_instance {
    my $gi_id = shift;

    # Create a CI to fully use a GI
    my $ci_id;
    if (script_output("nvidia-smi mig -cci -gi $gi_id") =~ /Successfully created compute instance ID\s+(\d*).*GPU instance ID\s+$gi_id/) {
        $ci_id = $1;
        assert_script_run("nvidia-smi mig -lci");
        script_run("nvidia-smi");
    }
    else {
        die "Fail to create a Compute Instance on GPU ID $gi_id";
    }
    record_info("CI created", "GI_ID: \$gi_id, CI_ID: \$ci_id");
    return $ci_id;
}

sub create_vgpu {
    my ($gpu, $mig_mode) = @_;

    # Find available vgpu types
    my $vf_count = ${mig_mode} ? '8' : '32';
    assert_script_run("cd /sys/bus/pci/devices/0000:$gpu/virtfn" . int(rand($vf_count)) . "/mdev_supported_types");
    assert_script_run('for i in *; do echo $i $(cat $i/name) available instance: $(cat $i/avail*); done');
    my $vgpu_type = ${mig_mode} ? "A.*-.*-.*C(ME)?" : "A.*-.*[CQ]";
    # We have NVIDIA A10 GPU card with SR-IOV feature and A30 with MIG mode
    # They behave a little differently in creating a vGPU device
    # Find the available vGPU instance
    my @avail_types = split /\n/, script_output("for i in *; do [ `cat \$i/avail*` -ne 0 ] && sed -n '/ ${vgpu_type}\$/p' \$i/name; done | cut -d '/' -f1", proceed_on_failure => 1);
    die "No available vGPU types for GPU $gpu!" if @{avail_types} == 0;

    # Choose a ramdom vgpu type and create a vGPU
    my $vgpu_type_name = ${avail_types [int(rand($#avail_types + 1))]};
    my $vgpu_type_id = script_output("grep -l '${vgpu_type_name}' */name | cut -d '/' -f1");
    my $vgpu_id = script_output('uuidgen');
    assert_script_run("echo ${vgpu_id} > ${vgpu_type_id}/create");

    # Verify if vGPU created successfully
    record_info("vGPU created", "$vgpu_type_name " . script_output("lsmdev"));
    assert_script_run("dmesg | tail");
    assert_script_run("nvidia-smi vgpu -q");

    return ${vgpu_id};
}

# Configure the guest
sub prepare_guest_for_vgpu_passthrough {
    my $vm = shift;

    die "vGPU only works on UEFI guests!" unless $vm =~ /uefi/i;

    # Save guest xml to /tmp/vm.xml, undefine the current one and define with the new xml
    my $vm_xml_file = "/tmp/$vm.xml";
    assert_script_run "virsh dumpxml --inactive $vm > $vm_xml_file";

    # VGPU can work in guests with non-secure boot guests
    if (script_output("virsh domstate $vm") eq "running") {
        validate_script_output("ssh root\@$vm 'mokutil --sb-state'", qr/SecureBoot disabled/);
    }

    # The UEFI guest created in virt test is ok for vGPU test
    assert_script_run("virsh shutdown $vm") unless script_output("virsh domstate $vm") eq "shut off";
    assert_script_run("virsh undefine $vm --keep-nvram", 30);

}

sub assign_vgpu_to_guest {
    my ($uuid, $vm, $slot) = @_;

    # Add the vgpu device section to guest configuration file
    my $vm_xml_file = "/tmp/$vm.xml";
    die "PCI slot '0x0a' has already been used" if script_run("grep \"slot='$slot'\" $vm_xml_file") == 0;
    my $vgpu_xml_section = "<hostdev mode='subsystem' type='mdev' model='vfio-pci' display='off'>\\\n  <source>\\\n    <address uuid='$uuid'/>\\\n  </source>\\\n  <address type='pci' domain='0x0000' bus='0x00' slot='$slot' function='0x0'/>\\\n</hostdev>";

    assert_script_run("sed -i \"/<devices>/a\\\\${vgpu_xml_section}\" $vm_xml_file");
    upload_logs($vm_xml_file);
    assert_script_run "virsh define $vm_xml_file";
    assert_script_run "virsh start $vm";
    wait_guest_online($vm);
    assert_script_run "ssh root\@$vm 'lspci | grep NVIDIA'";
    record_info("vGPU attached to $vm", script_output("ssh root\@$vm 'lspci | grep NVIDIA'"));
}

sub install_vgpu_grid_driver {
    my ($vm, $driver_url) = @_;

    # vGPU grid driver works in guests only without secure boot
    validate_script_output("ssh root\@$vm 'mokutil --sb-state'", qr/SecureBoot disabled/);

    # Download drivers from fileserver
    die "The vGPU driver URL requires to be in 'http://...' format!" unless $driver_url =~ /http:\/\/.*\/(.*\.run)/;
    my ${driver_file} = $1;

    # Check if the driver has been already installed
    if (script_run("ssh root\@$vm 'nvidia-smi'") == 0) {
        my $grid_version = script_output("ssh root\@$vm 'nvidia-smi -q | grep \"Driver Version\" | grep -oE \"[0-9.]+\"'");
        if (${driver_file} =~ /$grid_version/) {
            record_info("Warning", "vGPU grid driver $grid_version has already been loaded!", result => 'softfail');
            return;
        }
    }

    # Install dependencies seperately. It is easier to locate problem this way.
    download_script(${driver_file}, script_url => ${driver_url}, machine => $vm);
    assert_script_run "ssh root\@$vm 'zypper -n in kernel-default-devel'";
    assert_script_run "ssh root\@$vm 'zypper -n in libglvnd-devel'";
    # Install vGPU grid drivers without manual interactions
    assert_script_run("ssh root\@$vm './${driver_file} -s'");
    assert_script_run("ssh root\@$vm 'nvidia-smi'");
    record_info("vGPU Grid driver is installed successfully in $vm");
    # Verify
    assert_script_run("ssh root\@$vm 'lsmod | grep -i nvidia'");
}

sub detach_vgpu_from_guest {
    my ($slot, $vm) = @_;
    script_run("ssh root\@$vm 'poweroff'");
    script_retry("virsh domstate $vm | grep 'shut off'", timeout => 60, delay => 5, retry => 3, die => 0);
    assert_script_run("virt-xml $vm --remove-device --hostdev type=mdev,address.slot=$slot");
    assert_script_run("virsh start $vm");
    record_info("vGPU has been removed successfully from $vm");
    wait_guest_online($vm);
}

sub remove_vgpu {
    my $uuid = shift;
    assert_script_run("cd `find /sys/devices -type d -name $uuid`");
    assert_script_run("echo '1' > remove");
    script_run('cd ../mdev_supported_types/; for i in *; do echo "$i" $(cat $i/name) available: $(cat $i/avail*); done');
    die "Fatal: vGPU device $uuid is still alive!" if script_run("lsmdev | grep $uuid") == 0;
    record_info("vGPU removed", "$uuid has been removed from the host");
}

sub save_vgpu_device_status_logs {
    my $vm = shift;

    #vm configuration file
    enter_cmd("virsh dumpxml $vm > $log_dir/${vm}.xml");

    my $log_file = "log.txt";
    #logging device information in guest
    if (script_run("virsh domstate $vm | grep running") == 0) {
        script_run "echo `date` > $log_file";
        script_run "echo '***** Status & logs inside $vm *****' >> $log_file";
        my $debug_script = "vgpu_guest_logging.sh";
        download_script($debug_script, machine => $vm, proceed_on_failure => 1);
        script_run("timeout 25 ssh root\@$vm \"~/$debug_script\" >> $log_file 2>&1");
        # Save nvidia driver installer logs
        script_run("rsync root\@$vm:/var/log/nvidia-installer.log ${log_dir}/${vm}_nvidia-installer.log");
        script_run "mv $log_file $log_dir/${vm}_vgpu_device_status.txt";
    }
}

sub post_fail_hook {
    my $self = shift;
    diag("Module vgpu post fail hook starts.");

    # Make sure sol console is ok
    enter_cmd "echo DONE > /dev/$serialdev";
    reconnect_when_ssh_console_broken unless defined(wait_serial('DONE', timeout => 30));

    my $log_file = "$log_dir/host_vgpu_device_status.txt";
    print_cmd_output_to_file("virsh list --all", $log_file);
    print_cmd_output_to_file("nvidia-smi", $log_file);
    print_cmd_output_to_file("lspci -d 10de: -k", $log_file);
    print_cmd_output_to_file("ll /sys/bus/pci/devices/*/virtfn1/m*", $log_file);
    my $cmd = "journalctl --cursor-file /tmp/cursor.txt | grep -r -e 'kernel:' -e gpu -e nvidia | grep -v bash_history";
    script_run("echo '' >> $log_file");
    script_run("echo \"# $cmd\"");
    script_run("$cmd >> $log_file");
    script_run("cp /var/log/nvidia-installer.log $log_dir");
    save_vgpu_device_status_logs($_) foreach (keys %virt_autotest::common::guests);
    upload_virt_logs($log_dir, "vgpu");
    $self->SUPER::post_fail_hook;
    restore_original_guests() unless check_var('VGPU_TEST', 'short');
}

sub test_flags {
    #continue subsequent test in the case test restored
    return {fatal => 0};
}

1;
