# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Hyper-V bootloader with asset downloading
# Maintainer: Michal Nowak <mnowak@suse.com>

package bootloader_hyperv;

use base 'installbasetest';
use testapi;
use utils;
use strict;
use warnings;
use File::Basename;
use data_integrity_utils 'verify_checksum';

sub hyperv_cmd {
    my ($cmd, $args) = @_;
    $args->{ignore_return_code} ||= 0;
    my $ret = console('svirt')->run_cmd($cmd);
    diag "Command on Hyper-V returned: $ret";
    die 'Command on Hyper-V failed' unless ($args->{ignore_return_code} || !$ret);
    return $ret;
}

sub hyperv_cmd_with_retry {
    my ($cmd, $args) = @_;
    die 'Command not provided' unless $cmd;

    my $attempts = $args->{attempts} // 7;
    my $sleep = $args->{sleep} // 300;
    # Common messages
    my @msgs = $args->{msgs} // (
        'Failed to create the virtual hard disk',
        'The operation cannot be performed while the object is in use',
        'The process cannot access the file because it is being used by another process',
        'Access is denied.'
    );
    for my $retry (1 .. $attempts) {
        my ($ret, $stdout, $stderr) = console('svirt')->run_cmd($cmd, wantarray => 1);
        # return when powershell returns 0 (SUCCESS)
        return if $ret == 0;

        diag "Attempt $retry/$attempts: Command failed";
        my $msg_found = 0;
        foreach my $msg (@msgs) {
            diag "Looking for message: '$msg'";
            # Narrow the error message for an easy match
            # Remove Windows-style new lines (<CR><LF>)
            $stdout =~ s/\r\n//g;
            $stderr =~ s/\r\n//g;
            # Error message is not the expected error message in this cycle,
            # try the next one
            if ($stdout =~ /$msg/ || $stderr =~ /$msg/) {
                $msg_found = 1;
                # Error message is the expected one, sleep
                diag "Sleeping for $sleep seconds...";
                sleep $sleep;
                last;
            }
        }
        # Error we don't know if we should attempt to recover from
        die 'Command failed with unhandled error' unless $msg_found;
    }
    die 'Run out of attempts';
}

sub run {
    my $svirt = select_console('svirt');
    my $hyperv_intermediary = select_console('hyperv-intermediary');
    my $name = $svirt->name;

    # Following two variables specify where the root with expected directories is located.
    # Beware that we deal with Windows so backslash ('\') is used and multiple backslashes
    # in the path ('\\') are illegal (unless it's here in the test code or in shell
    # as a quotation).
    # Example: HYPERV_DISK="C:" HYPERV_ROOT="\\Users\\root\\VM"
    my $hyperv_disk = get_var('HYPERV_DISK', 'D:');
    my $root = $hyperv_disk . get_var('HYPERV_ROOT', '');
    my $root_nfs = 'N:';

    # Workaround before fix in svirt (https://github.com/os-autoinst/os-autoinst/pull/901) is deployed
    my $n = get_var('NUMDISKS', 1);
    set_var('NUMDISKS', defined get_var('RAIDLEVEL') ? 4 : $n);

    # Mount openQA NFS share to drive N:
    hyperv_cmd_with_retry("if not exist N: ( mount \\\\openqa.suse.de\\var\\lib\\openqa\\share\\factory N: )",
        {msgs => ('Another instance of this command is already running')});

    # Copy assets from NFS to Hyper-V cache
    for my $n ('', 1 .. 9) {
        # Look for {ISO,HDD}, {ISO,HDD}_1, ... variables
        $n = "_$n" if $n;
        if (my $iso = get_var("ISO$n")) {
            for my $isopath ("iso", "iso\\fixed") {
                # Copy ISO from NFS share to local cache on Hyper-V in 'network-restartable' mode
                my $basenameiso = basename($iso);
                # Using sha256sum to judge whether file is used by other job process.
                hyperv_cmd_with_retry("if exist $root\\cache\\$basenameiso ( sha256sum $root\\cache\\$basenameiso )", {msgs => ('Permission denied')});
                last
                  unless hyperv_cmd("if not exist $root\\cache\\$basenameiso ( copy /Z /Y $root_nfs\\$isopath\\$basenameiso $root\\cache\\ )",
                    {ignore_return_code => 1});
            }
        }
        if (my $hdd = get_var("HDD$n")) {
            my $basenamehdd = basename($hdd);
            for my $hddpath ("hdd", "hdd\\fixed") {
                my $basenamehdd_vhd = $basenamehdd =~ s/vhdx\.xz/vhdx/r;
                # If the image exists, do nothing
                last if hyperv_cmd("if exist $root\\cache\\$basenamehdd_vhd ( exit 1 )", {ignore_return_code => 1});
                # Copy HDD from NFS share to local cache on Hyper-V
                hyperv_cmd_with_retry("copy /z $root_nfs\\$hddpath\\$basenamehdd $root\\cache\\");
                # Decompress the XZ compressed image
                if ($hdd =~ m/vhdx\.xz/) {
                    record_info 'unxz', "Decompressing $root\\cache\\$basenamehdd";
                    my ($ret, $stdout, $stderr) = $svirt->run_cmd("xz --decompress --keep --verbose $root\\cache\\$basenamehdd", wantarray => 1);
                    defined($stderr) && $stderr =~ /xz: $root\\cache\\$basenamehdd: File exists/ && sleep 60;
                    last;
                }
            }
            # Make sure the disk file is present
            hyperv_cmd("if not exist $root\\cache\\" . $basenamehdd =~ s/vhdx\.xz/vhdx/r . " ( exit 1 )");
        }
    }
    # Verify checksums of the copied mediums
    my $errors = verify_checksum("$root\\cache\\");
    record_info("Checksum", $errors, result => 'fail') if $errors;
    # Delete copied mediums with wrong checksum
    foreach (split("\n", $errors)) {
        next unless ($_ =~ m/SHA256 checksum does not match for (.*):/);
        my $bad_image = basename(get_required_var($1));
        record_info("Delete medium", "Trying to delete wrong checksum downloaded medium $bad_image...", result => 'fail');
        hyperv_cmd_with_retry("del /F $root\\cache\\$bad_image");
    }

    my $xvncport = get_required_var('VIRSH_INSTANCE');
    my $iso = get_var('ISO') ? "$root\\cache\\" . basename(get_var('ISO')) : undef;
    my $ramsize = get_var('QEMURAM', 1024);
    my $cpucount = get_var('QEMUCPUS', 1);

    enter_cmd "mkdir -p ~/.vnc/";
    enter_cmd "vncpasswd -f <<<$testapi::password > ~/.vnc/passwd";
    enter_cmd "chmod 0600 ~/.vnc/passwd";
    enter_cmd 'pgrep -a Xvnc';
    enter_cmd "pvnc=\$(pgrep -f Xvnc[[:space:]]*:${xvncport}[[:space:]]*-geometry)";
    enter_cmd '[ -n "$pvnc" ] && kill -9 $pvnc';
    enter_cmd "Xvnc :$xvncport -geometry 1024x768 -pn -rfbauth ~/.vnc/passwd &";

    my $ps = 'powershell -Command';

    my ($ret, $winver, undef) = console('svirt')->run_cmd(qq/$ps (Get-WmiObject Win32_OperatingSystem).Version/, wantarray => 1);
    die 'Could not find Windows OS version!' if $ret != 0;

    $winver =~ s/\r\n//g;
    my $winserver;

    if ($winver =~ /6.3.*/) {
        $winserver = '2012r2';
    }
    elsif ($winver =~ /10.0.*/) {
        $winserver = '2016_or_2019';
    }
    else {
        die "Unsupported version: $winver";
    }

    hyperv_cmd("$ps Get-VM");
    hyperv_cmd("$ps Stop-VM -Force $name -TurnOff", {ignore_return_code => 1});
    hyperv_cmd(qq($ps "\$ProgressPreference='SilentlyContinue'; Remove-VM -Force $name"), {ignore_return_code => 1});

    my $hddsize = get_var('HDDSIZEGB', 20);
    my $vm_generation = get_var('UEFI') ? 2 : 1;
    my $hyperv_switch_name = get_var('HYPERV_VIRTUAL_SWITCH', 'ExternalVirtualSwitch');
    my @disk_paths = ();
    my $vmguid;
    if ($winserver eq '2012r2' || $winserver eq '2016_or_2019') {
        for my $n (1 .. get_var('NUMDISKS')) {
            hyperv_cmd("del /F $root\\cache\\${name}_${n}.vhd");
            hyperv_cmd("del /F $root\\cache\\${name}_${n}.vhdx");
            my $hdd = get_var("HDD_$n") ? "$root\\cache\\" . basename(get_var("HDD_$n")) =~ s/vhdx\.xz/vhdx/r : undef;
            if ($hdd) {
                my ($hddsuffix) = $hdd =~ /(\.[^.]+)$/;
                my $disk_path = "$root\\cache\\${name}_${n}${hddsuffix}";
                push @disk_paths, $disk_path;
                hyperv_cmd_with_retry(qq($ps "\$ProgressPreference='SilentlyContinue'; New-VHD -ParentPath $hdd -Path $disk_path -Differencing"));
            }
            else {
                my $disk_path = "$root\\cache\\${name}_${n}.vhdx";
                push @disk_paths, $disk_path;
                hyperv_cmd(qq($ps "\$ProgressPreference='SilentlyContinue'; New-VHD -Path $disk_path -Dynamic -SizeBytes ${hddsize}GB"));
            }
        }
        hyperv_cmd("$ps New-VM -VMName $name -Generation $vm_generation -SwitchName $hyperv_switch_name -MemoryStartupBytes ${ramsize}MB");
        # Create 'Standard' checkpoints with application's memory, on Hyper-V 2016
        # the default is 'Production' (i.e. snapshot on guest level).
        hyperv_cmd("$ps Set-VM -VMName $name -CheckpointType Standard") if $winserver eq '2016_or_2019';
        if ($iso) {
            hyperv_cmd("$ps Remove-VMDvdDrive -VMName $name -ControllerNumber 1 -ControllerLocation 0") unless $winserver eq '2012r2' and get_var('UEFI');
            hyperv_cmd("$ps Add-VMDvdDrive -VMName $name -Path $iso");
        }
        foreach my $disk_path (@disk_paths) {
            hyperv_cmd("$ps Add-VMHardDiskDrive -VMName $name -Path $disk_path");
        }
        hyperv_cmd("$ps Set-VMComPort -VMName $name -Number 1 -Path '\\\\.\\pipe\\$name'");
        ($ret, $vmguid, undef) = console('svirt')->run_cmd(qq/$ps (Get-VM -VMName $name).id.guid/, wantarray => 1);
        die "Have not find any GUID for $name" if $ret != 0;
    }
    else {
        die "Hyper-V $winserver is currently not supported";
    }

    # For Gen1 type machine: As we boot from IDE (then CD), HDD has to be connected to IDE
    # controller. However that leaves us with just three spare IDE channels for CDs, and one
    # of them has to be install CD, so: only three CDs can be attached to machine at once
    # (CDROM device can't be connected to SCSI, HDD can but we won't be able to bott from it).
    for my $n (1 .. 3) {
        if (my $addoniso = get_var("ISO_$n")) {
            hyperv_cmd("$ps Add-VMDvdDrive -VMName $name -Path $root\\cache\\" . basename($addoniso));
        }
    }

    hyperv_cmd("$ps Set-VMProcessor $name -Count $cpucount");

    if (get_var('UEFI')) {
        if ($winserver eq '2012r2' || get_var('DISABLE_SECUREBOOT')) {
            hyperv_cmd("$ps Set-VMFirmware $name -EnableSecureBoot Off");
        } else {
            hyperv_cmd("$ps Set-VMFirmware $name -EnableSecureBoot On -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'");
        }
        if (check_var('BOOTFROM', 'c')) {
            hyperv_cmd($ps . ' "' . "\$hd = Get-VMHardDiskDrive $name; Set-VMFirmware $name -BootOrder \$hd" . '"');
        }
        elsif (check_var('BOOTFROM', 'd')) {
            hyperv_cmd($ps . ' "' . "\$dvd = Get-VMDvdDrive $name; Set-VMFirmware $name -BootOrder \$dvd" . '"');
        }
        else {
            hyperv_cmd($ps . ' "' . "\$hd = Get-VMHardDiskDrive $name; Set-VMFirmware $name -BootOrder \$hd" . '"');
            hyperv_cmd($ps . ' "' . "\$dvd = Get-VMDvdDrive $name; Set-VMFirmware $name -FirstBootDevice \$dvd" . '"') if get_var('ISO');
        }
    }
    else {
        # All booteble devices has to be enumerated all the time...
        my $startup_order = (check_var('BOOTFROM', 'd') ? "'CD', 'IDE'" : "'IDE', 'CD'") . ", 'Floppy', 'LegacyNetworkAdapter'";
        hyperv_cmd($ps . ' "' . "Set-VMBios $name -StartupOrder @($startup_order)" . '"');
    }

    # remove stray whitespace characters
    $vmguid =~ s/[^[:print:]]+//;

    # xfreerdp should be run with fullscreen option (/f) so the needle match.
    # Typing this string takes so long that we would miss grub menu, so...
    my ($jobid) = get_required_var('NAME') =~ /(\d+)/;
    my $xfreerdp_log = "/tmp/${jobid}-xfreerdp-${name}-\$(date +%s).log";
    type_string "rm -fv xfreerdp_${name}_stop* xfreerdp_${name}.log; while true; do inotifywait xfreerdp_${name}_stop; DISPLAY=:$xvncport xfreerdp /u:"
      . get_var('HYPERV_USERNAME') . " /p:'"
      . get_var('HYPERV_PASSWORD') . "' /v:"
      . get_var('HYPERV_SERVER') . ' +auto-reconnect /auto-reconnect-max-retries:10'
      . " /cert-ignore /vmconnect:$vmguid /f -floatbar /log-level:DEBUG 2>&1 > $xfreerdp_log; echo $vmguid > xfreerdp_${name}_stop; done; ";

    hyperv_cmd_with_retry(qq($ps "\$ProgressPreference='SilentlyContinue'; Start-VM $name"));

    # ...we execute the command right after VMs starts.
    send_key 'ret';

    # Attach to serial console (a TCP port on HYPERV_SERVER).
    $svirt->attach_to_running({stop_vm => 1});
    # Get the VM's display.
    select_console('sut', await_console => 0);
}

1;
