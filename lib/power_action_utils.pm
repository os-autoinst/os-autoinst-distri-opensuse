=head1 power_action_utils

The module provides base and helper functions for powering off or rebooting a machine under test.

=cut
# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides base and helper functions for powering off or rebooting a machine under test.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package power_action_utils;

use base Exporter;
use Exporter;
use strict;
use warnings;
use utils;
use testapi;
use Utils::Architectures;
use Utils::Backends;
use version_utils qw(is_sle is_leap is_opensuse is_tumbleweed is_vmware is_jeos);
use Carp 'croak';

our @EXPORT = qw(
  prepare_system_shutdown
  reboot_x11
  poweroff_x11
  power_action
  assert_shutdown_and_restore_system
  assert_shutdown_with_soft_timeout
);

=head2 prepare_system_shutdown

 prepare_system_shutdown();

Need to kill ssh connection with backends like ipmi, spvm, pvm_hmc, s390x.

For s390_zkvm or xen, assign console($vnc_console) with C<disable_vnc_stalls>
and assign console('svirt') with C<stop_serial_grab>.

$vnc_console get required variable 'SVIRT_VNC_CONSOLE' before assignment.

=cut

sub prepare_system_shutdown {
    # kill the ssh connection before triggering reboot
    console('root-ssh')->kill_ssh if get_var('BACKEND', '') =~ /ipmi|spvm|pvm_hmc/;

    if (is_s390x) {
        if (is_backend_s390x) {
            # kill serial ssh connection (if it exists)
            eval { console('iucvconn')->kill_ssh unless get_var('BOOT_EXISTING_S390', ''); };
            diag('ignoring already shut down console') if ($@);
        }
        console('installation')->disable_vnc_stalls;
    }

    if (check_var('VIRSH_VMM_FAMILY', 'xen') || get_var('S390_ZKVM')) {
        my $vnc_console = get_required_var('SVIRT_VNC_CONSOLE');
        console($vnc_console)->disable_vnc_stalls;
        console('svirt')->stop_serial_grab;
    }
    return undef;
}

=head2 reboot_x11

 reboot_x11();

Reboot from Gnome Desktop and handle authentification scenarios during shutdown.

Run C<prepare_system_shutdown> if shutdown needs authentification.

=cut

sub reboot_x11 {
    my ($self) = @_;
    wait_still_screen;
    if (check_var('DESKTOP', 'gnome')) {
        # For systems with GNOME 40+, use mouse click instead of 'ctrl-alt-delete'.
        if (is_tumbleweed || is_sle('>=15-SP4') || is_leap('>=15.4')) {
            assert_and_click('reboot-power-icon');
            assert_and_click('reboot-power-menu');
            assert_and_click('reboot-click-restart');
        } else {
            send_key_until_needlematch 'logoutdialog', 'ctrl-alt-delete', 8, 10;    # reboot
        }
        my $repetitions = assert_and_click_until_screen_change 'logoutdialog-reboot-highlighted';
        record_soft_failure 'poo#19082' if ($repetitions > 0);
        if (get_var("SHUTDOWN_NEEDS_AUTH")) {

            assert_screen 'shutdown-auth';
            wait_still_screen(3);    # 981299#c41
            type_string $testapi::password, max_interval => 5;
            wait_still_screen(3);    # 981299#c41
            if (get_var('REBOOT_DEBUG')) {
                wait_screen_change {
                    # Extra assert_and_click (with right click) to check the correct number of characters is typed and open up the 'show text' option
                    assert_and_click('reboot-auth-typed', button => 'right');
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

=head2 poweroff_x11

Power off desktop.

Handle each desktop differently for kde, gnome, xfce, lxde, lxqt, enlightenment, awesome, mate, minimalx.

Work around issue with CD-ROM pop-up: bsc#1137230 and make sure that s390 SUT shutdown correctly.

=cut

sub poweroff_x11 {
    my ($self) = @_;
    wait_still_screen;

    if (check_var("DESKTOP", "kde")) {
        send_key "ctrl-alt-delete";    # shutdown
        assert_screen_with_soft_timeout('logoutdialog', timeout => 90, soft_timeout => 15, bugref => 'bsc#1091933');
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
        send_key 'ret';
    }

    if (check_var("DESKTOP", "lxde")) {
        # opens logout dialog
        x11_start_program('lxsession-logout', target_match => 'logoutdialog');
        send_key "ret";
    }

    if (check_var("DESKTOP", "lxqt")) {
        # Handle bsc#1137230
        if (check_screen 'authorization_failed') {
            record_soft_failure 'bsc#1137230 - "Authorization failed" pop-up shown';
            assert_and_click 'authorization_failed_ok_btn';
        }
        elsif (check_screen 'authentication-required') {
            record_soft_failure 'bsc#1137230 - "Authentication required" pop-up shown';
            assert_and_click 'authentication-required_cancel_btn';
        }
        # opens logout dialog
        x11_start_program('shutdown', target_match => [qw(authentication-required authorization_failed lxqt_shutdowndialog)], match_timeout => 60);
        # we have typing issue because of poor performance, to record this if happens.
        # Double check for bsc#1137230
        if (match_has_tag 'authorization_failed' || 'authentication-required') {
            croak "bsc#1137230, CD-ROM pop-up displayed at shutdown, authorization failed";
        }
        elsif (match_has_tag 'lxqt_shutdowndialog') {
            assert_and_click 'shutdowndialog-yes';
        }
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
        assert_and_click 'mate_shutdown_btn';
    }

    if (check_var("DESKTOP", "minimalx")) {
        send_key "ctrl-alt-delete";    # logout dialog
        assert_screen 'logoutdialog', 10;
        send_key "alt-d";    # shut_d_own
        assert_screen 'logout-confirm-dialog', 10;
        send_key "alt-o";    # _o_k
    }
}

=head2 handle_livecd_reboot_failure

 handle_livecd_reboot_failure();

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
        enter_cmd "reboot";
        save_screenshot;
    }
}

=head2 power_action

 power_action($action [,observe => $observe] [,keepconsole => $keepconsole] [,textmode => $textmode]);

Executes the selected power action (e.g. poweroff, reboot).

If C<$observe> is set, the function expects that the specified C<$action> was already executed by
another actor and the function just makes sure the system shuts down, restarts etc. properly.

C<$keepconsole> prevents a console change, which we do by default to make sure that a system with a GUI
desktop which was in text console at the time of C<power_action> call, is switched to the expected
console, that is 'root-console' for textmode, 'x11' otherwise. The actual execution happens in a shell
for textmode or with GUI commands otherwise unless explicitly overridden by setting C<$textmode> to either 0 or 1.

=cut

sub power_action {
    my ($action, %args) = @_;
    $args{observe} //= 0;
    $args{keepconsole} //= 0;
    $args{textmode} //= check_var('DESKTOP', 'textmode');
    $args{first_reboot} //= 0;
    die "'action' was not provided" unless $action;

    prepare_system_shutdown;

    unless ($args{keepconsole}) {
        select_console $args{textmode} ? 'root-console' : 'x11';
    }

    unless ($args{observe}) {
        if ($args{textmode}) {
            enter_cmd "$action";
        }
        elsif ($action eq 'reboot') {
            reboot_x11;
        }
        elsif ($action eq 'poweroff') {
            if (is_backend_s390x) {
                record_info('poo#114439', 'Temporary workaround, because shutdown module is marked as failed on s390x backend when shutting down from GUI.');
                select_console 'root-console';
                enter_cmd "$action";
            }
            else {
                poweroff_x11;
            }
        }
    }

    my $soft_fail_data;
    my $shutdown_timeout = 60;

    if (is_sle('15-sp1+') && check_var('DESKTOP', 'textmode') && ($action eq 'poweroff')) {
        $soft_fail_data = {bugref => 'bsc#1158145', soft_timeout => 60, timeout => $shutdown_timeout *= 3};
    }

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

    # Kubeadm also requires some extra time
    if (check_var 'SYSTEM_ROLE', 'kubeadm') {
        $soft_fail_data = {bugref => 'poo#55127', soft_timeout => 90, timeout => $shutdown_timeout *= 2};
    }

    # Sometimes QEMU CD-ROM pop-up is displayed on shutdown, see bsc#1137230
    if (is_opensuse && check_screen 'qemu-cd-rom-authentication-required') {
        $soft_fail_data = {bugref => 'bsc#1137230', soft_timeout => 60, timeout => $shutdown_timeout *= 5};
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
        if (check_var('DESKTOP', 'minimalx') && check_screen('shutdown-wall', timeout => 30)) {
            record_soft_failure 'bsc#1076817 manually shutting down';
            select_console 'root-console';
            systemctl 'poweroff';
        }

        assert_shutdown_with_soft_timeout($soft_fail_data) if ($action eq 'poweroff');
        # We should only reset consoles if the system really rebooted.
        # Otherwise the next select_console will check for a login prompt
        # instead of handling the still logged in system.
        handle_livecd_reboot_failure if get_var('LIVECD') && $action eq 'reboot';
        # Look aside before we are sure 'sut' console on VMware is ready, see poo#47150
        select_console('svirt') if is_vmware && $action eq 'reboot';
        reset_consoles;
        if ((check_var('VIRSH_VMM_FAMILY', 'xen') || get_var('S390_ZKVM')) && $action ne 'poweroff') {
            console('svirt')->start_serial_grab;
        }
        # When 'sut' is ready, select it
        # GRUB's serial terminal configuration relies on installation/add_serial_console.pm
        if (is_vmware && $action eq 'reboot') {
            die 'GRUB not found on serial console' unless (is_jeos || wait_serial('GNU GRUB', 180));
            select_console('sut');
        }
    }
}

=head2 assert_shutdown_and_restore_system

 assert_shutdown_and_restore_system($action, $shutdown_timeout);

VNC connection to SUT (the 'sut' console) is terminated on Xen via svirt backend
and we have to re-connect *after* the restart, otherwise we end up with stalled
VNC connection. The tricky part is to know *when* the system is already booting.

Default $action is reboot, $shutdown_timeout is timeout for shutdown, default value is 60 seconds.

=cut
# VNC connection to SUT (the 'sut' console) is terminated on Xen via svirt
# backend and we have to re-connect *after* the restart, otherwise we end up
# with stalled VNC connection. The tricky part is to know *when* the system
# is already booting.
sub assert_shutdown_and_restore_system {
    my ($action, $shutdown_timeout) = @_;
    $action //= 'reboot';
    $shutdown_timeout //= 60;
    my $vnc_console = get_required_var('SVIRT_VNC_CONSOLE');
    console($vnc_console)->disable_vnc_stalls;
    assert_shutdown($shutdown_timeout);
    if ($action eq 'reboot') {
        reset_consoles;
        my $svirt = console('svirt');
        # Set disk as a primary boot device
        if (is_s390x or get_var('NETBOOT')) {
            $svirt->change_domain_element(os => initrd => undef);
            $svirt->change_domain_element(os => kernel => undef);
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
a soft failure is recorded with the message C<$args->{soft_failure_reason}>.

After that, assert_shutdown continues until the (hard) timeout C<$args->{timeout}> is hit.

This makes sense when a shutdown sporadically takes longer then it normally should take
and the proper statistics of such cases should be gathered instead of just increasing a timeout.

If C<$args->{soft_timeout}> is not specified, then the default assert_shutdown is executed.

Example:

 assert_shutdown_with_soft_timeout({timeout => 300, soft_timeout => 60, bugref => 'bsc#123456'});

=cut

sub assert_shutdown_with_soft_timeout {
    my ($args) = @_;
    $args->{timeout} //= is_s390x ? 600 : get_var('DEBUG_SHUTDOWN') ? 180 : 60;
    $args->{soft_timeout} //= 0;
    $args->{bugref} //= "No bugref specified";
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
