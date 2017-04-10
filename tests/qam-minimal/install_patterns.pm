# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


# Summary: QAM Minimal test in openQA
#    it prepares minimal instalation, boot it, install tested incident , try
#    reboot and update system with all released updates.
#
#    with QAM_MINIMAL=full it also installs gnome-basic, base, apparmor and
#    x11 patterns and reboot system to graphical login + start console and
#    x11 tests
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use base "opensusebasetest";

use strict;

use utils;
use qam;
use testapi;

sub install_packages {
    my $patch_info = shift;
    my $pattern    = qr/\s+(.+)(?!\.src)\..*\s<\s.*/;

    # loop over packages in patchinfo and try installation
    foreach my $line (split(/\n/, $patch_info)) {
        if (my ($package) = $line =~ $pattern) {
            script_run("zypper -n in $package", 700);
            save_screenshot;
        }
    }
}

sub run {
    my ($self) = @_;
    my $patch = get_required_var('INCIDENT_PATCH');

    select_console 'root-console';

    pkcon_quit;
    zypper_call("ref");
    zypper_call("pt");
    save_screenshot;

    zypper_call("in -t pattern base x11 gnome-basic apparmor", exitcode => [0, 102], timeout => 2000);

    assert_script_run("systemctl set-default graphical.target");
    script_run('sed -i -r "s/^DISPLAYMANAGER=\"\"/DISPLAYMANAGER=\"gdm\"/" /etc/sysconfig/displaymanager');
    script_run('sed -i -r "s/^DISPLAYMANAGER_AUTOLOGIN/#DISPLAYMANAGER_AUTOLOGIN/" /etc/sysconfig/displaymanager');
    script_run('sed -i -r "s/^DEFAULT_WM=\"icewm\"/DEFAULT_VM=\"\"/" /etc/sysconfig/windowmanager');
    # now we have gnome installed - restore DESKTOP variable
    set_var('DESKTOP', get_var('FULL_DESKTOP'));

    my $patch_status = script_output("zypper -n info -t patch $patch");
    if ($patch_status =~ /Status\s*:\s+[Nn]ot\s[Nn]eeded/) {
        install_packages($patch_status);
    }

    prepare_system_reboot;
    type_string "reboot\n";
    $self->wait_boot;
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    select_console('root-console');

    assert_script_run "save_y2logs /tmp/y2logs-fail.tar.bz2";
    upload_logs "/tmp/y2logs-fail.tar.bz2";
}

1;
