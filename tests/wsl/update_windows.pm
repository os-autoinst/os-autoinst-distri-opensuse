# SUSE's openQA tests
#
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Update Windows base image
# Maintainer: qa-c <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use testapi;

sub run {
    my $self = shift;

    my $vbs_url = data_url("wsl/UpdateInstall.vbs");
    $self->open_powershell_as_admin;
    $self->run_in_powershell(cmd => "Invoke-WebRequest -Uri \"$vbs_url\" -OutFile \"C:\\UpdateInstall.vbs\"");
    $self->run_in_powershell(
        cmd => 'cd \\; $port.WriteLine($(cscript .\\UpdateInstall.vbs /Automate))',
        code => sub {
            die("Update script finished unespectedly or timed out...")
              unless wait_serial("The update process finished with value 1", timeout => 3600);
        }
    );
    save_screenshot;
    # The script autoreboot fails, so there's need to reboot manually
    $self->reboot_or_shutdown(1);
    while (defined(check_screen('windows-updating', 60))) {
        bmwqemu::diag("Applying updates while shutting down the machine...");
    }
    $self->wait_boot_windows;

    # Shutdown
    $self->reboot_or_shutdown;
}

1;
