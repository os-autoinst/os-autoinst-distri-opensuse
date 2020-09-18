# SUSE's openQA tests
#
# Copyright © 2012-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install VDMP tools to enable network drivers correctly.
#
# Maintainer: mmartins <mmartins@suse.com>

use base 'windowsbasetest';
use strict;
use warnings;
use testapi;
use mmapi;

sub run {
    my $self = shift;

    assert_screen "windows-installed-ok", timeout => 90;
    $self->windows_server_login_Administrator;

    #install VMDP drivers and reboot
    $self->open_powershell_as_admin;
    $self->run_in_powershell(cmd => 'e:\VMDP-WIN-2.5.2\setup.exe', tags => 'win-ad-powershell');
    wait_screen_change { assert_and_click 'VMDP-focus'; };
    send_key 'alt-n';
    wait_screen_change { assert_and_click 'VMDP-reboot'; };

    #login
    assert_screen "windows-installed-ok", timeout => 90;    #waiting boot
    $self->windows_server_login_Administrator;

    #simple check ip address
    $self->open_powershell_as_admin;
    $self->run_in_powershell(cmd => 'ipconfig', tags => 'win-ad-powershell');

}

1;
