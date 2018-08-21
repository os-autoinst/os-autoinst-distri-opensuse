# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The module provides base and helper functions for powering off or rebooting a machine under test.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>
package power_action_utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use utils;
use testapi;
use version_utils 'is_sle';

our @EXPORT = qw(
  prepare_system_shutdown
  reboot_x11
  poweroff_x11
  power_action
  assert_shutdown_and_restore_system
);

# in some backends we need to prepare the reboot/shutdown
sub prepare_system_shutdown {
    # kill the ssh connection before triggering reboot
    console('root-ssh')->kill_ssh if check_var('BACKEND', 'ipmi') || check_var('BACKEND', 'spvm');

    if (check_var('ARCH', 's390x')) {
        if (check_var('BACKEND', 's390x')) {
            # kill serial ssh connection (if it exists)
            eval { console('iucvconn')->kill_ssh unless get_var('BOOT_EXISTING_S390', ''); };
            diag('ignoring already shut down console') if ($@);
        }
        console('installation')->disable_vnc_stalls;
    }
    if (check_var('BACKEND', 'svirt')) {
        my $vnc_console = get_required_var('SVIRT_VNC_CONSOLE');
        console($vnc_console)->disable_vnc_stalls;
        console('svirt')->stop_serial_grab;
    }
}

sub reboot_x11 {
    my ($self) = @_;
    wait_still_screen;
    if (check_var('DESKTOP', 'gnome')) {
        send_key_until_needlematch 'logoutdialog', 'ctrl-alt-delete', 7, 10;    # reboot
        my $repetitions = assert_and_click_until_screen_change 'logoutdialog-reboot-highlighted';
        record_soft_failure 'poo#19082' if ($repetitions > 0);

        if (get_var("SHUTDOWN_NEEDS_AUTH")) {
            assert_screen 'shutdown-auth';
            wait_still_screen(3);                                               # 981299#c41
            type_string $testapi::password, max_interval => 5;
            wait_still_screen(3);                                               # 981299#c41
            wait_screen_change {
                # Extra assert_and_click (with right click) to check the correct number of characters is typed and open up the 'show text' option
                assert_and_click 'reboot-auth-typed', 'right';
            };
            wait_screen_change {
                # Click the 'Show Text' Option to enable the display of the typed text
                assert_and_click 'reboot-auth-showtext';
            };
            # Check the password is correct
            assert_screen 'reboot-auth-correct-password';
            # we need to kill ssh for iucvconn here,
            # because after pressing return, the system is down
            prepare_system_shutdown;

            send_key 'ret';    # Confirm
        }
    }
}

sub poweroff_x11 {
    my ($self) = @_;
    wait_still_screen;

    if (check_var("DESKTOP", "kde")) {
        send_key "ctrl-alt-delete";    # shutdown
        assert_screen_with_soft_timeout('logoutdialog', timeout => 90, soft_timeout => 15, 'bsc#1091933');
        assert_and_click 'sddm_shutdown_option_btn';
    }

    if (check_var("DESKTOP", "gnome")) {
        send_key "ctrl-alt-delete";
        assert_screen 'logoutdialog', 15;
        assert_and_click 'gnome-shell_shutdown_btn';

        if (get_var("SHUTDOWN_NEEDS_AUTH")) {
            assert_screen 'shutdown-auth';
            type_password;
            # we need to kill all open ssh connections before the system shuts down
            prepare_system_shutdown;
            send_key "ret";
        }
    }

    if (check_var("DESKTOP", "xfce")) {
        for (1 .. 5) {
            send_key "alt-f4";    # opens log out popup after all windows closed
        }
        assert_screen 'logoutdialog';
        wait_screen_change { type_string "\t\t" };    # select shutdown

        # assert_screen 'test-shutdown-1', 3;
        type_string "\n";
    }

    if (check_var("DESKTOP", "lxde")) {
        # opens logout dialog
        x11_start_program('lxsession-logout', target_match => 'logoutdialog');
        send_key "ret";
    }

    if (check_var("DESKTOP", "lxqt")) {
        # opens logout dialog
        x11_start_program('shutdown', target_match => 'lxqt_logoutdialog');
        send_key "ret";
    }
    if (check_var("DESKTOP", "enlightenment")) {
        send_key "ctrl-alt-delete";    # shutdown
        assert_screen 'logoutdialog', 15;
        assert_and_click 'enlightenment_shutdown_btn';
    }

    if (check_var('DESKTOP', 'awesome')) {
        assert_and_click 'awesome-menu-main';
        assert_and_click 'awesome-menu-system';
        assert_and_click 'awesome-menu-shutdown';
    }

    if (check_var("DESKTOP", "mate")) {
        x11_start_program("mate-session-save --shutdown-dialog", valid => 0);
        send_key "ctrl-alt-delete";    # shutdown
        assert_screen 'mate_logoutdialog', 15;
        assert_and_click 'mate_shutdown_btn';
    }

    if (check_var("DESKTOP", "minimalx")) {
        send_key "ctrl-alt-delete";    # logout dialog
        assert_screen 'logoutdialog', 10;
        send_key "alt-d";              # shut_d_own
        assert_screen 'logout-confirm-dialog', 10;
        send_key "alt-o";              # _o_k
    }

    if (check_var('BACKEND', 's390x')) {
        # make sure SUT shut down correctly
        console('x3270')->expect_3270(
            output_delim => qr/.*SIGP stop.*/,
            timeout      => 30
        );

    }
}

=head2 handle_livecd_reboot_failure

Handle a potential failure on a live CD related to boo#993885 that the reboot
action from a desktop session does not work and we are stuck on the desktop.

=cut
sub handle_livecd_reboot_failure {
    mouse_hide;
    wait_still_screen;
    assert_screen([qw(generic-desktop-after_installation grub2)]);
    if (match_has_tag('generic-desktop-after_installation')) {
        record_soft_failure 'boo#993885 Kde-Live net installer does not reboot after installation';
        select_console 'install-shell';
        type_string "reboot\n";
        save_screenshot;
    }
}

=head2 power_action

    power_action($action [,observe => $observe] [,keepconsole => $keepconsole] [,textmode => $textmode]);

Executes the selected power action (e.g. poweroff, reboot). If C<$observe> is
set the function expects that the specified C<$action> was already executed by
another actor and the function justs makes sure the system shuts down, restart
etc. properly. C<$keepconsole> prevents a console change, which we do by
default to make sure that a system with a GUI desktop which was in text
console at the time of C<power_action> call, is switched to the expected
console, that is 'root-console' for textmode, 'x11' otherwise. The actual
execution happens in a shell for textmode or with GUI commands otherwise
unless explicitly overridden by setting C<$textmode> to either 0 or 1.

=cut
sub power_action {
    my ($action, %args) = @_;
    $args{observe}      //= 0;
    $args{keepconsole}  //= 0;
    $args{textmode}     //= check_var('DESKTOP', 'textmode');
    $args{first_reboot} //= 0;
    die "'action' was not provided" unless $action;
    prepare_system_shutdown;
    unless ($args{keepconsole}) {
        select_console $args{textmode} ? 'root-console' : 'x11';
    }
    unless ($args{observe}) {
        if ($args{textmode}) {
            type_string "$action\n";
        }
        else {
            if ($action eq 'reboot') {
                reboot_x11;
            }
            elsif ($action eq 'poweroff') {
                poweroff_x11;
            }
        }
    }
    # Shutdown takes longer than 60 seconds on SLE 15
    my $shutdown_timeout = 60;
    if (is_sle('15+') && check_var('DESKTOP', 'gnome') && ($action eq 'poweroff')) {
        record_soft_failure('bsc#1055462');
        $shutdown_timeout *= 3;
    }
    # The timeout is increased as shutdown takes longer on Live CD
    if (get_var('LIVECD')) {
        $shutdown_timeout *= 4;
    }
    if (get_var("OFW") && check_var('DISTRI', 'opensuse') && check_var('DESKTOP', 'gnome') && get_var('PUBLISH_HDD_1')) {
        $shutdown_timeout *= 3;
        record_soft_failure("boo#1057637 shutdown_timeout increased to $shutdown_timeout (s) expecting to complete.");
    }
    # no need to redefine the system when we boot from an existing qcow image
    # Do not redefine if autoyast or s390 zKVM reboot, as did initial reboot already
    if (check_var('VIRSH_VMM_FAMILY', 'kvm')
        || check_var('VIRSH_VMM_FAMILY', 'xen')
        || (get_var('S390_ZKVM') && !get_var('BOOT_HDD_IMAGE') && !get_var('AUTOYAST') && $args{first_reboot}))
    {
        assert_shutdown_and_restore_system($action, $shutdown_timeout);
    }
    else {
        assert_shutdown($shutdown_timeout) if $action eq 'poweroff';
        # We should only reset consoles if the system really rebooted.
        # Otherwise the next select_console will check for a login prompt
        # instead of handling the still logged in system.
        handle_livecd_reboot_failure if get_var('LIVECD') && $action eq 'reboot';
        reset_consoles;
        if (check_var('BACKEND', 'svirt') && $action ne 'poweroff') {
            console('svirt')->start_serial_grab;
        }
    }
}

# VNC connection to SUT (the 'sut' console) is terminated on Xen via svirt
# backend and we have to re-connect *after* the restart, otherwise we end up
# with stalled VNC connection. The tricky part is to know *when* the system
# is already booting.
sub assert_shutdown_and_restore_system {
    my ($action, $shutdown_timeout) = @_;
    $action           //= 'reboot';
    $shutdown_timeout //= 60;
    my $vnc_console = get_required_var('SVIRT_VNC_CONSOLE');
    console($vnc_console)->disable_vnc_stalls;
    assert_shutdown($shutdown_timeout);
    if ($action eq 'reboot') {
        reset_consoles;
        my $svirt = console('svirt');
        # Set disk as a primary boot device
        if (check_var('ARCH', 's390x') or get_var('NETBOOT')) {
            $svirt->change_domain_element(os => initrd  => undef);
            $svirt->change_domain_element(os => kernel  => undef);
            $svirt->change_domain_element(os => cmdline => undef);
            $svirt->change_domain_element(on_reboot => undef);
            $svirt->define_and_start;
        }
        else {
            $svirt->define_and_start;
            select_console($vnc_console);
        }
    }
}


