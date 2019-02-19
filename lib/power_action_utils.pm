# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
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
use version_utils qw(is_sle is_vmware);

our @EXPORT = qw(
  prepare_system_shutdown
  reboot_x11
  poweroff_x11
  power_action
  assert_shutdown_and_restore_system
  assert_shutdown_with_soft_timeout
);

# in some backends we need to prepare the reboot/shutdown
sub prepare_system_shutdown {
    # kill the ssh connection before triggering reboot
    console('root-ssh')->kill_ssh if get_var('BACKEND', '') =~ /ipmi|spvm/;

    if (check_var('ARCH', 's390x')) {
        if (check_var('BACKEND', 's390x')) {
            # kill serial ssh connection (if it exists)
            eval { console('iucvconn')->kill_ssh unless get_var('BOOT_EXISTING_S390', ''); };
            diag('ignoring already shut down console') if ($@);
        }
        console('installation')->disable_vnc_stalls;
    }
    if (check_var('VIRSH_VMM_FAMILY', 'xen')) {
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
            if (get_var('REBOOT_DEBUG')) {
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
            }
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

        if (!check_shutdown()) {
            record_soft_failure 'bsc#1076817 manually shutting down';
            select_console 'root-console';
            systemctl 'poweroff';
        }
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
    my $soft_fail_data;
    my $shutdown_timeout = 60;
    # Shutdown takes longer than 60 seconds on SLE12 SP4 and SLE 15
    if (is_sle('12+') && check_var('DESKTOP', 'gnome') && ($action eq 'poweroff')) {
        $soft_fail_data = {bugref => 'bsc#1055462', soft_timeout => 60, timeout => $shutdown_timeout *= 3};
    }
    # The timeout is increased as shutdown takes longer on Live CD
    if (get_var('LIVECD')) {
        $soft_fail_data = {soft_timeout => 60, timeout => $shutdown_timeout *= 4, bugref => "bsc#1096241"};
    }
    if (get_var("OFW") && check_var('DISTRI', 'opensuse') && check_var('DESKTOP', 'gnome') && get_var('PUBLISH_HDD_1')) {
        $soft_fail_data = {bugref => 'bsc#1057637', soft_timeout => 60, timeout => $shutdown_timeout *= 3};
    }
    # no need to redefine the system when we boot from an existing qcow image
    # Do not redefine if autoyast or s390 zKVM reboot, as did initial reboot already
    if (check_var('VIRSH_VMM_FAMILY', 'kvm')
        || check_var('VIRSH_VMM_FAMILY', 'xen')
        || (get_var('S390_ZKVM') && !get_var('BOOT_HDD_IMAGE') && !get_var('AUTOYAST') && $args{first_reboot}))
    {
        assert_shutdown_and_restore_system($action, $shutdown_timeout *= 3);
    }
    else {
        assert_shutdown_with_soft_timeout($soft_fail_data) if ($action eq 'poweroff');
        # We should only reset consoles if the system really rebooted.
        # Otherwise the next select_console will check for a login prompt
        # instead of handling the still logged in system.
        handle_livecd_reboot_failure if get_var('LIVECD') && $action eq 'reboot';
        # Look aside before we are sure 'sut' console on VMware is ready, see poo#47150
        select_console('svirt') if is_vmware && $action eq 'reboot';
        reset_consoles;
        if (check_var('VIRSH_VMM_FAMILY', 'xen') && $action ne 'poweroff') {
            console('svirt')->start_serial_grab;
        }
        # When 'sut' is ready, select it
        if (is_vmware && $action eq 'reboot') {
            wait_serial('GNU GRUB') || die 'GRUB not found on serial console';
            select_console('sut');
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

=head2 assert_shutdown_with_soft_timeout

  assert_shutdown_with_soft_timeout([$args]);

  $args = {[timeout => $timeout] [,soft_timeout => $soft_timeout] [,bugref => $bugref] [,soft_failure_reason => $soft_failure_reason]}

Extending assert_shutdown with a soft timeout. When C<$args->{soft_timeout}> is reached,
a soft failure is recorded with the message C<$args->{soft_failure_reason}>. After
that, assert_shutdown continues until the (hard) timeout C<$args->{timeout}> is hit.

This makes sense when a shutdown sporadically takes longer then it normally should take
and the proper statistics of such cases should be gathered instead of just increasing
a timeout.

If C<$args->{soft_timeout}> is not specified, then the default assert_shutdown is executed.

Example:

  assert_shutdown_with_soft_timeout({timeout => 300, soft_timeout => 60, bugref => 'bsc#123456'});

=cut

sub assert_shutdown_with_soft_timeout {
    my ($args) = @_;
    $args->{timeout}      //= 60;
    $args->{soft_timeout} //= 0;
    $args->{bugref}       //= "No bugref specified";
    if ($args->{soft_timeout}) {
        diag("assert_shutdown_with_soft_timeout(): soft_timeout=" . $args->{soft_timeout});
        die "soft timeout has to be smaller than timeout" unless ($args->{soft_timeout} < $args->{timeout});
        my $ret = check_shutdown $args->{soft_timeout};
        return if $ret;
        $args->{soft_failure_reason} //= "$args->{bugref}: Machine didn't shut down within $args->{soft_timeout} sec";
        record_soft_failure "$args->{soft_failure_reason}";
    }
    assert_shutdown($args->{timeout} - $args->{soft_timeout});
}


