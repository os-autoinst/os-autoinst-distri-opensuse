# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Hyper-V bootloader with asset downloading
# Maintainer: Michal Nowak <mnowak@suse.com>

use base 'installbasetest';
use testapi;
use utils;
use strict;
use warnings;
use File::Basename;

sub hyperv_cmd {
    my ($cmd, $args) = @_;
    $args->{ignore_return_code} ||= 0;
    my $ret = console('svirt')->run_cmd($cmd);
    diag "Command on Hyper-V returned: $ret";
    die 'Command on Hyper-V failed' unless ($args->{ignore_return_code} || !$ret);
    return $ret;
}

sub run {
    my $svirt               = select_console('svirt');
    my $hyperv_intermediary = select_console('hyperv-intermediary');
    my $name                = $svirt->name;

    # Mount openQA NFS share to drive N:
    hyperv_cmd("if not exist N: ( mount \\\\openqa.suse.de\\var\\lib\\openqa\\share\\factory N: )");

    # Copy assets from NFS to Hyper-V cache
    for my $n ('', 1 .. 9) {
        $n = "_$n" if $n;    # Look for {ISO,HDD}, {ISO,HDD}_1, ... variables
        if (my $iso = get_var("ISO$n")) {
            for my $isopath ("iso", "iso\\fixed") {
                # Copy ISO from NFS share to local cache on Hyper-V in 'network-restartable' mode
                my $basenameiso = basename($iso);
                last unless hyperv_cmd("if not exist D:\\cache\\$basenameiso ( copy /Z /Y N:\\$isopath\\$basenameiso D:\\cache\\ )", {ignore_return_code => 1});
            }
        }
        if (my $hdd = get_var("HDD$n")) {
            for my $hddpath ("hdd", "hdd\\fixed") {
                my $basenamehdd          = basename($hdd);
                my $basenamehdd_vhd      = $basenamehdd =~ s/vhdfixed\.xz/vhd/r;
                my $basenamehdd_vhdfixed = $basenamehdd =~ s/\.xz//r;
                # If the image exists, do nothing
                last if hyperv_cmd("if exist D:\\cache\\$basenamehdd_vhd ( exit 1 )", {ignore_return_code => 1});
                # Copy HDD from NFS share to local cache on Hyper-V
                next if hyperv_cmd("copy N:\\$hddpath\\$basenamehdd D:\\cache\\", {ignore_return_code => 1});
                # Decompress the XZ compressed image & rename it to .vhd
                last if $hdd !~ m/vhdfixed\.xz/;
                hyperv_cmd("xz --decompress --keep --verbose D:\\cache\\$basenamehdd");
                # Rename .vhdfixed to .vhd
                hyperv_cmd("move /Y D:\\cache\\$basenamehdd_vhdfixed D:\\cache\\$basenamehdd_vhd");
                # No need to attempt anything further, if we just moved
                # the file to the correct location
                last;
            }
            # Make sure the .vhd file is present
            hyperv_cmd("if not exist D:\\cache\\" . basename($hdd) =~ s/vhdfixed\.xz/vhd/r . " ( exit 1 )");
        }
    }

    # Because we likely wrote dozens of GB of zeros to disk, we have to wait some time for
    # the disk to write all the data, otherwise the test would be unstable due to the load.
    # Check average disk load for some time to make sure all the data are in cold on disk.
    select_console('svirt');
    type_string("typeperf \"\\PhysicalDisk(1 D:)\\Avg\. Disk Bytes/Write\"\n");
    assert_screen('no-hyperv-disk-load', 600);
    send_key 'ctrl-c';
    assert_screen 'hyperv-typeperf-command-finished';
    select_console('hyperv-intermediary');

    my $xvncport = get_required_var('VIRSH_INSTANCE');
    my $hdd1     = get_var('HDD_1') ? 'd:\\cache\\' . basename(get_var('HDD_1')) =~ s/vhdfixed\.xz/vhd/r : undef;
    my $hdd1size = get_var('HDDSIZEGB');
    my $iso      = get_var('ISO') ? 'd:\\cache\\' . basename(get_var('ISO')) : undef;
    my $ramsize  = get_var('QEMURAM');
    my $cpucount = get_var('QEMUCPUS');

    type_string "mkdir -p ~/.vnc/\n";
    type_string "vncpasswd -f <<<$testapi::password > ~/.vnc/passwd\n";
    type_string "chmod 0600 ~/.vnc/passwd\n";
    type_string "pkill -f \"Xvnc :$xvncport\"; pkill -9 -f \"Xvnc :$xvncport\"\n";
    type_string "Xvnc :$xvncport -geometry 1024x768 -pn -rfbauth ~/.vnc/passwd &\n";

    my $ps = 'powershell -Command';

    my ($winserver, $winver, $vmguid);

    $winver = $svirt->get_cmd_output("cmd /C ver");
    if (grep { /Microsoft Windows \[Version 6.3.*\]/ } $winver) {
        $winserver = 2012;
    }
    else {
        die "Unsupported version: $winver";
    }

    hyperv_cmd("$ps Get-VM");
    hyperv_cmd("$ps Stop-VM -Force $name -TurnOff", {ignore_return_code => 1});
    hyperv_cmd("$ps Remove-VM -Force $name",        {ignore_return_code => 1});
    hyperv_cmd("del d:\\cache\\${name}a.vhd d:\\cache\\${name}a.vhdx");

    if ($winserver eq "2012") {
        my $vm_generation = get_var('UEFI') ? 2 : 1;
        my $hyperv_switch_name = get_var('HYPERV_VIRTUAL_SWITCH', 'ExternalVirtualSwitch');
        if ($hdd1) {
            hyperv_cmd("$ps New-VHD -ParentPath $hdd1 -Path d:\\cache\\${name}a.vhd -Differencing");
            hyperv_cmd("$ps New-VM -Name $name -Generation $vm_generation -VHDPath d:\\cache\\${name}a.vhd "
                  . "-SwitchName $hyperv_switch_name -MemoryStartupBytes ${ramsize}MB");
        }
        else {
            hyperv_cmd("$ps New-VM -Name $name -Generation $vm_generation -NewVHDPath d:\\cache\\${name}a.vhdx "
                  . "-NewVHDSizeBytes ${hdd1size}GB -SwitchName $hyperv_switch_name -MemoryStartupBytes ${ramsize}MB");
            if (get_var('UEFI')) {
                hyperv_cmd("$ps Add-VMDvdDrive -VMName $name -Path $iso");
            }
            else {
                hyperv_cmd("$ps Remove-VMDvdDrive -VMName $name -ControllerNumber 1 -ControllerLocation 0");    # Removes DvdDrive on 1:0
                hyperv_cmd("$ps Add-VMDvdDrive -VMName $name -Path $iso -ControllerNumber 0 -ControllerLocation 1");
            }
        }
        hyperv_cmd("$ps Set-VMComPort -VMName $name -Number 1 -Path '\\\\.\\pipe\\$name'");
        $vmguid = $svirt->get_cmd_output("$ps (Get-VM -VMName $name).id.guid");
    }
    else {
        die "Hyper-V $winserver is not supported version";
    }

    # For Gen1 type machine: As we boot from IDE (then CD), HDD has to be connected to IDE
    # controller. However that leaves us with just three spare IDE channels for CDs, and one
    # of them has to be install CD, so: only three CDs can be attached to machine at once
    # (CDROM device can't be connected to SCSI, HDD can but we won't be able to bott from it).
    for my $n (1 .. 3) {
        if (my $addoniso = get_var("ISO_$n")) {
            hyperv_cmd("$ps Add-VMDvdDrive -VMName $name -Path d:\\cache\\" . basename($addoniso));
        }
    }

    hyperv_cmd("$ps Set-VMProcessor $name -Count $cpucount");
    # All booteble devices has to be enumerated all the time...
    my $startup_order = (check_var('BOOTFROM', 'd') ? "'CD', 'VHD'" : "'VHD', 'CD'") . ", 'Floppy', 'NetworkAdapter'";
    if (get_var('UEFI')) {
        hyperv_cmd("$ps Set-VMFirmware $name -EnableSecureBoot off ");
    }
    else {
        hyperv_cmd($ps . ' "' . "Set-VMBios $name -StartupOrder @($startup_order)" . '"');
    }

    # remove stray whitespace characters
    $vmguid =~ s/[^[:print:]]+//;

    # xfreerdp should be run with fullscreen option (/f) so the needle match.
    # Typing this string takes so long that we would miss grub menu, so...
    type_string "rm -fv xfreerdp_${name}_stop* xfreerdp_${name}.log; while true; do inotifywait xfreerdp_${name}_stop; DISPLAY=:$xvncport xfreerdp /u:"
      . get_var('HYPERV_USERNAME') . " /p:'"
      . get_var('HYPERV_PASSWORD') . "' /v:"
      . get_var('HYPERV_SERVER')
      . " /cert-ignore /vmconnect:$vmguid /f 2>&1 >> xfreerdp_${name}.log; echo $vmguid > xfreerdp_${name}_stop; done";
    #      . " /cert-ignore /jpeg /jpeg-quality:100 /fast-path:1 /bpp:32 /vmconnect:$vmguid /f";

    hyperv_cmd("$ps Start-VM $name");

    # ...we execute the command right after VMs starts.
    send_key 'ret';

    # Attach to serial console (a TCP port on HYPERV_SERVER).
    $svirt->attach_to_running({stop_vm => 1});
    # Get the VM's display.
    select_console('sut', await_console => 0);
}

1;
