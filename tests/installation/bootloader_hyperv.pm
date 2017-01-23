# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Hyper-V bootloader
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "installbasetest";

use testapi;
use utils;

use strict;
use warnings;

use File::Basename;
use Net::Telnet ();

sub run() {
    my $svirt = select_console('svirt');
    my $name  = $svirt->name;

    my $file = basename(get_var('HDD_1'));

    if (is_jeos) {
        type_string "mkdir -p ~/.vnc/\n";
        type_string "vncpasswd -f <<<$testapi::password > ~/.vnc/passwd\n";
        type_string "chmod 600 ~/.vnc/passwd\n";
        type_string "pkill -f \"Xvnc :1\"; pkill -9 -f \"Xvnc :1\"\n";
        type_string "Xvnc :1 -geometry 1024x768 -pn -rfbauth ~/.vnc/passwd &\n";

        my $ps   = "powershell -Command";
        my $wait = "";

        my ($t, $winserver, @winver, @vmguid);

        $t = new Net::Telnet(Timeout => 60);

        $t->open(get_var('HYPERV_SERVER'));
        $t->login(get_var('HYPERV_USERNAME'), get_var('HYPERV_PASSWORD'));

        # This is the expected shell prompt: '$ ' otherwise cmd() will timeout.
        # * in Bash: PS1='$ ' in ~/.bash_profile
        # * as a CMD.exe: set user var PROMPT to $$$S
        $t->prompt('/\$ /i');

        @winver = $t->cmd("cmd /C ver");

        if (grep { /Microsoft Windows \[Version 6.1.*\]/ } @winver) {
            $wait      = "-Wait";
            $winserver = 2008;
        }
        elsif (grep { /Microsoft Windows \[Version 6.3.*\]/ } @winver) {
            $winserver = 2012;
        }
        elsif (grep { /Microsoft Windows \[Version 10.0.*\]/ } @winver) {
            $winserver = 2016;
        }
        else {
            die "Unsupported version: @winver";
        }

        $t->cmd("$ps Get-VM");
        # It fails on WS 2008 R2 for Stopped VMs
        $t->cmd("$ps Stop-VM -Force $name $wait");
        $t->cmd("$ps Remove-VM -Force $name");
        if ($winserver eq "2008") {
            $t->cmd("$ps New-VM -Name $name");
            $t->cmd("$ps Add-VMNic -VM $name (Select-VMSwitch)");
            $t->cmd("$ps Add-VMDisk -VM $name -ControllerID 0 -Lun 0 $file");
            $t->cmd("$ps Set-VMSerialPort -VM $name -PortNumber 1 -Connection '\\\\.\\pipe\\$name'");
            @vmguid = $t->cmd("$ps (Get-VM -VMName $name).name");
        }
        elsif ($winserver eq "2012") {
            $t->cmd("$ps New-VM -Name $name -VHDPath $file -SwitchName *");
            $t->cmd("$ps Set-VMComPort -VMName $name -Number 1 -Path '\\\\.\\pipe\\$name'");
            @vmguid = $t->cmd("$ps (Get-VM -VMName $name).id.guid");
        }
        elsif ($winserver eq "2016") {
            $t->cmd("$ps New-VM -Name $name -VHDPath $file -SwitchName \\*");
            $t->cmd("$ps Set-VMComPort -VMName $name -Number 1 -Path '\\\\.\\pipe\\$name'");
            @vmguid = $t->cmd("$ps \\(Get-VM -VMName $name\\).id.guid");
        }

        # remove stray whitespace characters
        @vmguid = map { join(' ', split(' ')) } @vmguid;
        # find a GUID like this 52eac3c0-da62-4054-bf6a-ad99bdb07f82 in the array
        until (grep { m/([A-Fa-f0-9]{8}[\-][A-Fa-f0-9]{4}[\-][A-Fa-f0-9]{4}[\-][A-Fa-f0-9]{4}[\-]([A-Fa-f0-9]){12})/gi }
              $vmguid[0])
        {
            shift(@vmguid);
        }
        # remove telnet transfer remnants
        $vmguid[0] =~ s/[^[:print:]]+//;

        # xfreerdp should be run with fullscreen option (/f) so the needle match but
        # due to bug https://github.com/FreeRDP/FreeRDP/issues/3362 on WS 2008 R2 we
        # have to start xfreerdp without the /f option and toggle to fullscreen later.
        # Typing this string takes so long that we miss grub menu at all...
        type_string "DISPLAY=:1 xfreerdp /u:"
          . get_var('HYPERV_USERNAME') . " /p:'"
          . get_var('HYPERV_PASSWORD') . "' /v:"
          . get_var('HYPERV_SERVER')
          . " /cert-ignore /jpeg /jpeg-quality:100 /fast-path:1 /bpp:32 /vmconnect:$vmguid[0]";

        $t->cmd("$ps Start-VM $name $wait");
        $t->close;

        # ...so we execute the command right after VMs starts.
        type_string "\n";

        # attach to console (a TCP port on HYPERV_SERVER)
        $svirt->attach_to_running;

        select_console('sut');
    }
}

1;
