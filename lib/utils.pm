# Copyright (C) 2015-2018 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package utils;

use base Exporter;
use Exporter;

use strict;

use testapi qw(is_serial_terminal :DEFAULT);
use mm_network;
use version_utils qw(is_caasp is_leap is_tumbleweed is_sle is_sle12_hdd_in_upgrade leap_version_at_least sle_version_at_least is_storage_ng);

our @EXPORT = qw(
  check_console_font
  clear_console
  type_string_slow
  type_string_very_slow
  save_svirt_pty
  type_line_svirt
  unlock_if_encrypted
  prepare_system_shutdown
  get_netboot_mirror
  zypper_call
  fully_patch_system
  minimal_patch_system
  workaround_type_encrypted_passphrase
  ensure_unlocked_desktop
  install_to_other_at_least
  is_bridged_networking
  ensure_fullscreen
  reboot_x11
  poweroff_x11
  power_action
  assert_shutdown_and_restore_system
  assert_screen_with_soft_timeout
  pkcon_quit
  systemctl
  addon_decline_license
  addon_license
  addon_products_is_applicable
  noupdatestep_is_applicable
  validate_repos
  turn_off_kde_screensaver
  random_string
  handle_login
  handle_logout
  handle_emergency
  service_action
  assert_gui_app
  install_all_from_repo
  run_scripted_command_slow
  get_root_console_tty
  get_x11_console_tty
  OPENQA_FTP_URL
  setup_static_network
  arrays_differ
  ensure_serialdev_permissions
  assert_and_click_until_screen_change
);


# USB kbd in raw mode is rather slow and QEMU only buffers 16 bytes, so
# we need to type very slowly to not lose keypresses.

# arbitrary slow typing speed for bootloader prompt when not yet scrolling
use constant SLOW_TYPING_SPEED => 13;

# type even slower towards the end to ensure no keybuffer overflow even
# when scrolling within the boot command line to prevent character
# mangling
use constant VERY_SLOW_TYPING_SPEED => 4;

# openQA internal ftp server url
our $OPENQA_FTP_URL = "ftp://openqa.suse.de";

my $svirt_pty_saved = 0;

=head2 save_svirt_pty
save the pty device within the svirt shell session so that we can refer to the
correct pty pointing to the first tty, e.g. for password entry for encrypted
partitions and rewriting the network definition of zKVM instances.

Does not work on Hyper-V.
=cut
sub save_svirt_pty {
    return if check_var('VIRSH_VMM_FAMILY', 'hyperv');
    my $name = console('svirt')->name;
    type_string "pty=`virsh dumpxml $name 2>/dev/null | grep \"console type=\" | sed \"s/'/ /g\" | awk '{ print \$5 }'`\n";
    type_string "echo \$pty\n";
}

sub type_line_svirt {
    my ($string, %args) = @_;
    type_string "echo $string > \$pty\n";
    if ($args{expect}) {
        wait_serial($args{expect}, $args{timeout}) || die $args{fail_message} // 'expected \'' . $args{expect} . '\' not found';
    }
}

sub unlock_if_encrypted {
    my (%args) = @_;
    $args{check_typed_password} //= 0;

    return unless get_var("ENCRYPT");

    if (check_var('ARCH', 's390x') && check_var('BACKEND', 'svirt')) {
        my $password = $testapi::password;

        # enter passphrase twice (before grub and after grub) if full disk is encrypted
        if (get_var('FULL_LVM_ENCRYPT')) {
            wait_serial("Please enter passphrase for disk.*", 100);
            type_line_svirt "$password";
        }
        wait_serial("Please enter passphrase for disk.*", 100);
        type_line_svirt "$password";
    }
    else {
        assert_screen("encrypted-disk-password-prompt", 200);
        type_password;    # enter PW at boot
        save_screenshot;
        assert_screen 'encrypted_disk-typed_password' if $args{check_typed_password};
        send_key "ret";
    }
}

sub systemctl {
    my ($command, %args) = @_;
    my $expect_false = $args{expect_false} ? '!' : '';
    assert_script_run "$expect_false systemctl --no-pager $command", timeout => $args{timeout}, fail_message => $args{fail_message};
}

sub turn_off_kde_screensaver {
    x11_start_program('kcmshell5 screenlocker', target_match => [qw(kde-screenlock-enabled screenlock-disabled)]);
    if (match_has_tag('kde-screenlock-enabled')) {
        assert_and_click('kde-disable-screenlock');
    }
    assert_screen 'screenlock-disabled';
    send_key("alt-o");
}

# 'ctrl-l' does not get queued up in buffer. If this happens to fast, the
# screen would not be cleared
sub clear_console {
    type_string "clear\n";
}

# in some backends we need to prepare the reboot/shutdown
sub prepare_system_shutdown {
    # kill the ssh connection before triggering reboot
    console('root-ssh')->kill_ssh if check_var('BACKEND', 'ipmi');

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

# assert_gui_app (optionally installs and) starts an application, checks it started
# and closes it again. It's the most minimalistic way to test a GUI application
# Mandatory parameter: application: the name of the application.
# Optional parameters are:
#   install: boolean    => does the application have to be installed first? Especially
#                         on live images where we want to ensure the disks are complete
#                         the parameter should not be set to true - otherwise we might
#                         mask the fact that the app is not on the media
#   exec_param: string => When calling the application, pass this parameter on the command line
#   remain: boolean    => If set to true, do not close the application when tested it is
#                         running. This can be used if the application shall be tested further

sub assert_gui_app {
    my ($application, %args) = @_;
    ensure_installed($application) if $args{install};
    x11_start_program("$application $args{exec_param}", target_match => "test-$application-started");
    send_key "alt-f4" unless $args{remain};
}

# 13.2, Leap 42.1, SLE12 GA&SP1 have problems with setting up the
# console font, we need to call systemd-vconsole-setup to workaround
# that
sub check_console_font {
    # we do not await the console here, as we have to expect the font to be broken
    # for the needle to match
    select_console('root-console', await_console => 0);

    # if this command failed, we're not in a console (e.g. in a svirt
    # ssh connection) and don't see the console font but the local
    # xterm font - no reason to change
    return if script_run 'showconsolefont';
    assert_screen [qw(broken-console-font correct-console-font)];
    if (match_has_tag 'broken-console-font') {
        assert_script_run("/usr/lib/systemd/systemd-vconsole-setup");
        assert_screen 'correct-console-font';
    }
}

sub type_string_slow {
    my ($string) = @_;

    type_string $string, SLOW_TYPING_SPEED;
}

sub type_string_very_slow {
    my ($string) = @_;

    type_string $string, VERY_SLOW_TYPING_SPEED;

    # the bootloader prompt line is very delicate with typing especially when
    # scrolling. We are typing very slow but this could still pose problems
    # when the worker host is utilized so better wait until the string is
    # displayed before continuing
    # For the special winter grub screen with moving penguins
    # `wait_still_screen` does not work so we just revert to sleeping a bit
    # instead of waiting for a still screen which is never happening. Sleeping
    # for 3 seconds is less waste of time than waiting for the
    # wait_still_screen to timeout, especially because wait_still_screen is
    # also scaled by TIMEOUT_SCALE which we do not need here.
    if (get_var('WINTER_IS_THERE')) {
        sleep 3;
    }
    else {
        wait_still_screen 1;
    }
}

sub get_netboot_mirror {
    my $m_protocol = get_var('INSTALL_SOURCE', 'http');
    return get_var('MIRROR_' . uc($m_protocol));
}

# function wrapping 'zypper -n' with allowed return code, timeout and logging facility
# first parammeter is required command , all others are named and provided as hash
# for example : zypper_call("up", exitcode => [0,102,103], log => "zypper.log");
# up -- zypper -n up -- update system
# exitcode -- allowed return code values
# log -- capture log and store it in zypper.log
# dumb_term -- pipes through cat if set to 1 and log is not set. This is a  workaround
# to get output without any ANSI characters in zypper before 1.14.1. See boo#1055315.

sub zypper_call {
    my $command          = shift;
    my %args             = @_;
    my $allow_exit_codes = $args{exitcode} || [0];
    my $timeout          = $args{timeout} || 700;
    my $log              = $args{log};
    my $dumb_term        = $args{dumb_term};

    my $str = hashed_string("ZN$command");
    my $redirect = is_serial_terminal() ? '' : " > /dev/$serialdev";

    if ($log) {
        script_run("zypper -n $command | tee /tmp/$log; echo $str-\${PIPESTATUS}-$redirect", 0);
    }
    elsif ($dumb_term) {
        script_run("zypper -n $command | cat; echo $str-\${PIPESTATUS}-$redirect", 0);
    }
    else {
        script_run("zypper -n $command; echo $str-\$?-$redirect", 0);
    }

    my $ret = wait_serial(qr/$str-\d+-/, $timeout);

    upload_logs("/tmp/$log") if $log;

    if ($ret) {
        my ($ret_code) = $ret =~ /$str-(\d+)/;
        unless (grep { $_ == $ret_code } @$allow_exit_codes) {
            upload_logs('/var/log/zypper.log');
            die "'zypper -n $command' failed with code $ret_code";
        }

        return $ret_code;
    }
    die "zypper did not return an exitcode";
}

sub fully_patch_system {
    # first run, possible update of packager -- exit code 103
    zypper_call('patch --with-interactive -l', exitcode => [0, 102, 103], timeout => 1500);
    # second run, full system update
    zypper_call('patch --with-interactive -l', exitcode => [0, 102], timeout => 6000);
}

# zypper doesn't offer --updatestack-only option before 12-SP1, use patch for sp0 to update packager
sub minimal_patch_system {
    my (%args) = @_;
    $args{version_variable} //= 'VERSION';
    if (sle_version_at_least('12-SP1', version_variable => $args{version_variable})) {
        zypper_call('patch --with-interactive -l --updatestack-only', exitcode => [0, 102, 103], timeout => 1500, log => 'minimal_patch.log');
    }
    else {
        zypper_call('patch --with-interactive -l', exitcode => [0, 102, 103], timeout => 1500, log => 'minimal_patch.log');
    }
}

=head2 workaround_type_encrypted_passphrase

    workaround_type_encrypted_passphrase()

Record soft-failure for unresolved feature fsc#320901 which we think is
important and then unlock encrypted boot partitions if we expect it to be
encrypted. This condition is met on 'storage-ng' which by default puts the
boot partition within the encrypted LVM same as in test scenarios where we
explicitly create an LVM including boot (C<FULL_LVM_ENCRYPT>). C<ppc64le> was
already doing the same by default also in the case of pre-storage-ng but not
anymore for storage-ng.

=cut
sub workaround_type_encrypted_passphrase {
    # nothing to do if the boot partition is not encrypted in FULL_LVM_ENCRYPT
    return if get_var('UNENCRYPTED_BOOT');
    return if !get_var('ENCRYPT') && !get_var('FULL_LVM_ENCRYPT');
    # ppc64le on pre-storage-ng boot was part of encrypted LVM
    return if !get_var('FULL_LVM_ENCRYPT') && !is_storage_ng && !get_var('OFW');
    # If the encrypted disk is "just activated" it does not mean that the
    # installer would propose an encrypted installation again
    return if get_var('ENCRYPT_ACTIVATE_EXISTING') && !get_var('ENCRYPT_FORCE_RECOMPUTE');
    record_soft_failure 'workaround https://fate.suse.com/320901' if sle_version_at_least('12-SP4');
    unlock_if_encrypted;
}

# if stay under tty console for long time, then check
# screen lock is necessary when switch back to x11
# all possible options should be handled within loop to get unlocked desktop
sub ensure_unlocked_desktop {
    my $counter = 10;
    while ($counter--) {
        assert_screen [qw(displaymanager displaymanager-password-prompt generic-desktop screenlock gnome-screenlock-password)], no_wait => 1;
        if (match_has_tag 'displaymanager') {
            if (check_var('DESKTOP', 'minimalx')) {
                type_string "$username";
                save_screenshot;
            }
            send_key 'ret';
        }
        if ((match_has_tag 'displaymanager-password-prompt') || (match_has_tag 'gnome-screenlock-password')) {
            if ($password ne '') {
                type_password;
                assert_screen [qw(locked_screen-typed_password login_screen-typed_password)];
            }
            send_key 'ret';
        }
        if (match_has_tag 'generic-desktop') {
            send_key 'esc';
            unless (get_var('DESKTOP', '') =~ m/minimalx|awesome|enlightenment|lxqt|mate/) {
                # gnome might show the old 'generic desktop' screen although that is
                # just a left over in the framebuffer but actually the screen is
                # already locked so we have to try something else to check
                # responsiveness.
                # open run command prompt (if screen isn't locked)
                mouse_hide(1);
                send_key 'alt-f2';
                if (check_screen 'desktop-runner') {
                    send_key 'esc';
                    assert_screen 'generic-desktop';
                }
                else {
                    next;    # most probably screen is locked
                }
            }
            last;            # desktop is unlocked, mission accomplished
        }
        if (match_has_tag 'screenlock') {
            wait_screen_change {
                send_key 'esc';    # end screenlock
            };
        }
        wait_still_screen 2;       # slow down loop
        die 'ensure_unlocked_desktop repeated too much. Check for X-server crash.' if ($counter eq 1);    # die loop when generic-desktop not matched
    }
}

#Check the real version of the test machine is at least some value, rather than the VERSION variable
#It is for version checking for tests with variable "INSTALL_TO_OTHERS".
sub install_to_other_at_least {
    my $version = shift;

    if (!check_var("INSTALL_TO_OTHERS", "1")) {
        return 0;
    }

    #setup the var for real VERSION
    my $real_installed_version = get_var("REPO_0_TO_INSTALL");
    $real_installed_version =~ /.*SLES?-(\d+-SP\d+)-.*/m;
    $real_installed_version = $1;
    set_var("REAL_INSTALLED_VERSION", $real_installed_version);
    bmwqemu::save_vars();

    return sle_version_at_least($version, version_variable => "REAL_INSTALLED_VERSION");
}

sub is_bridged_networking {
    my $ret = 0;
    if (check_var('BACKEND', 'svirt') and !check_var('ARCH', 's390x')) {
        my $vmm_family = get_required_var('VIRSH_VMM_FAMILY');
        $ret = ($vmm_family =~ /xen|vmware|hyperv/);
    }
    # Some needles match hostname which we can't set permanently with bridge.
    set_var('BRIDGED_NETWORKING', 1) if $ret;
    return $ret;
}

sub ensure_fullscreen {
    my (%args) = @_;
    $args{tag} //= 'yast2-windowborder';
    # for ssh-X using our window manager we need to handle windows explicitly
    if (check_var('VIDEOMODE', 'ssh-x')) {
        assert_screen($args{tag});
        my $console = select_console("installation");
        $console->fullscreen({window_name => 'YaST2*'});
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
        # Set disk as a primary boot device
        console('svirt')->change_domain_element(os => boot => {dev => 'hd'});
        console('svirt')->define_and_start;
        select_console($vnc_console);
    }
}

sub assert_and_click_until_screen_change {
    my ($mustmatch, $wait_change, $repeat) = @_;
    $wait_change //= 2;
    $repeat      //= 3;
    my $i = 0;

    for (; $i < $repeat; $i++) {
        my $changed = wait_screen_change(sub { assert_and_click $mustmatch }, $wait_change);
        last if $changed;
    }

    return $i;
}

sub reboot_x11 {
    my ($self) = @_;
    wait_still_screen;
    if (check_var('DESKTOP', 'gnome')) {
        send_key_until_needlematch 'logoutdialog', 'ctrl-alt-delete', 7, 10;    # reboot
        my $repetitions = assert_and_click_until_screen_change 'logoutdialog-reboot-highlighted';
        record_soft_failure 'poo#19082' if ($repetitions > 0);

        if (get_var("SHUTDOWN_NEEDS_AUTH")) {
            if (check_screen('shutdown-auth', 15)) {
                wait_still_screen(3);                                           # 981299#c41
                type_string $testapi::password, max_interval => 5;
                wait_still_screen(3);                                           # 981299#c41
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
            else {
                record_soft_failure 'bsc#1062788';
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
        assert_screen 'logoutdialog', 15;

        if (get_var("PLASMA5")) {
            assert_and_click 'sddm_shutdown_option_btn';
            if (check_screen([qw(sddm_shutdown_option_btn sddm_shutdown_btn)], 3)) {
                # sometimes not reliable, since if clicked the background
                # color of button should changed, thus check and click again
                if (match_has_tag('sddm_shutdown_option_btn')) {
                    assert_and_click 'sddm_shutdown_option_btn';
                }
                # plasma < 5.8
                elsif (match_has_tag('sddm_shutdown_btn')) {
                    assert_and_click 'sddm_shutdown_btn';
                }
            }
        }
        else {
            type_string "\t";
            assert_screen "kde-turn-off-selected", 2;
            type_string "\n";
        }
    }

    if (check_var("DESKTOP", "gnome")) {
        send_key "ctrl-alt-delete";
        assert_screen 'logoutdialog', 15;
        assert_and_click 'gnome-shell_shutdown_btn';

        if (get_var("SHUTDOWN_NEEDS_AUTH")) {
            if (check_screen('shutdown-auth', 15)) {
                type_password;
            }
            else {
                record_soft_failure 'bsc#1062788';
            }

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
    $args{observe}     //= 0;
    $args{keepconsole} //= 0;
    $args{textmode}    //= check_var('DESKTOP', 'textmode');
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
    if (is_sle('15+') && check_var('DESKTOP', 'gnome')) {
        record_soft_failure('bsc#1055462');
        $shutdown_timeout *= 3;
    }
    if (get_var("OFW") && check_var('DISTRI', 'opensuse') && check_var('DESKTOP', 'gnome') && get_var('PUBLISH_HDD_1')) {
        $shutdown_timeout *= 3;
        record_soft_failure("boo#1057637 shutdown_timeout increased to $shutdown_timeout (s) expecting to complete.");
    }
    if (check_var('VIRSH_VMM_FAMILY', 'xen')) {
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

=head2 assert_screen_with_soft_timeout

  assert_screen_with_soft_timeout($mustmatch [,timeout => $timeout] [, bugref => $bugref] [,soft_timeout => $soft_timeout] [,soft_failure_reason => $soft_failure_reason]);

Extending assert_screen with a soft timeout. When C<$soft_timeout> is hit, a
soft failure is recorded with the message C<$soft_failure_reason> but
assert_screen continues until the (hard) timeout C<$timeout> is hit. This
makes sense when an assert screen should find a screen within a lower time but
still should not fail and continue until the hard timeout, e.g. to discover
performance issues.

Example:

  assert_screen_with_soft_timeout('registration-found', timeout => 300, soft_timeout => 60, bugref => 'bsc#123456');

=cut
sub assert_screen_with_soft_timeout {
    my ($mustmatch, %args) = @_;
    # as in assert_screen
    $args{timeout}             //= 30;
    $args{soft_timeout}        //= 0;
    $args{soft_failure_reason} //= "$args{bugref}: needle(s) $mustmatch not found within $args{soft_timeout}";
    if ($args{soft_timeout}) {
        die "soft timeout has to be smaller than timeout" unless ($args{soft_timeout} < $args{timeout});
        my $ret = check_screen $mustmatch, $args{soft_timeout};
        return $ret if $ret;
        record_soft_failure "$args{soft_failure_reason}";
    }
    return assert_screen $mustmatch, $args{timeout} - $args{soft_timeout};
}

sub pkcon_quit {
    script_run("systemctl mask packagekit; systemctl stop packagekit; while pgrep packagekitd; do sleep 1; done");
}

sub addon_decline_license {
    if (get_var("HASLICENSE")) {
        if (check_screen 'next-button-is-active', 5) {
            send_key $cmd{next};
            assert_screen "license-refuse";
            send_key 'alt-n';    # no, don't refuse agreement
            wait_still_screen 2;
            send_key $cmd{accept};    # accept license
        }
        else {
            wait_still_screen 2;
            send_key $cmd{accept};    # accept license
        }
    }
}

sub addon_license {
    my ($addon)  = @_;
    my $uc_addon = uc $addon;                      # variable name is upper case
    my @tags     = ('import-untrusted-gpg-key');
    push @tags, (get_var("BETA_$uc_addon") ? "addon-betawarning-$addon" : "addon-license-$addon");
  license: {
        do {
            # Soft-fail on SLE-15 if license is not there.
            if (sle_version_at_least('15') && !check_screen \@tags) {
                record_soft_failure 'bsc#1057223';
                return;
            }
            assert_screen \@tags;
            if (match_has_tag('import-untrusted-gpg-key')) {
                record_soft_failure 'untrusted gpg key';
                wait_screen_change { send_key 'alt-t' };
            }
            elsif (match_has_tag("addon-betawarning-$addon")) {
                wait_screen_change { send_key 'ret' };
                assert_screen 'addon-license-beta';
                last;
            }
        } until (match_has_tag("addon-license-$addon"));
    }
    addon_decline_license;
    wait_still_screen 2;
    send_key $cmd{next};
}

sub addon_products_is_applicable {
    return !get_var('LIVECD') && get_var('ADDONURL');
}

sub noupdatestep_is_applicable {
    return !get_var("UPGRADE");
}

sub random_string {
    my ($self, $length) = @_;
    $length //= 4;
    my @chars = ('A' .. 'Z', 'a' .. 'z', 0 .. 9);
    return join '', map { @chars[rand @chars] } 1 .. $length;
}

sub handle_login {
    assert_screen 'displaymanager';    # wait for DM, then try to login
    mouse_hide();
    wait_still_screen;
    if (get_var('ROOTONLY')) {
        if (check_screen 'displaymanager-username-notlisted', 10) {
            record_soft_failure 'bgo#731320/boo#1047262 "not listed" Login screen for root user is not intuitive';
            assert_and_click 'displaymanager-username-notlisted';
            wait_still_screen 3;
        }
        type_string "root\n";
    }
    elsif (get_var('DM_NEEDS_USERNAME')) {
        type_string "$username\n";
    }
    elsif (check_var('DESKTOP', 'gnome')) {
        # DMs in condition above have to select user
        if (is_sle('15+') || (is_leap && leap_version_at_least('15.0')) || is_tumbleweed) {
            assert_and_click "displaymanager-$username";
            record_soft_failure 'bgo#657996 - user account not selected by default, have to use mouse to login';
        }
        else {
            send_key 'ret';
        }
    }
    assert_screen 'displaymanager-password-prompt', no_wait => 1;
    type_password;
    send_key "ret";
}

sub handle_logout {
    # hide mouse for clean logout needles
    mouse_hide();
    # logout
    if (check_var('DESKTOP', 'gnome') || check_var('DESKTOP', 'lxde')) {
        my $command = check_var('DESKTOP', 'gnome') ? 'gnome-session-quit' : 'lxsession-logout';
        my $target_match = check_var('DESKTOP', 'gnome') ? undef : 'logoutdialog';
        x11_start_program($command, target_match => $target_match);    # opens logout dialog
    }
    else {
        my $key = check_var('DESKTOP', 'xfce') ? 'alt-f4' : 'ctrl-alt-delete';
        send_key_until_needlematch 'logoutdialog', "$key";             # opens logout dialog
    }
    assert_and_click 'logout-button';                                  # press logout
}

# Handle emergency mode
sub handle_emergency {
    if (match_has_tag('emergency-shell')) {
        # get emergency shell logs for bug, scp doesn't work
        script_run "cat /run/initramfs/rdsosreport.txt > /dev/$serialdev";
        die "hit emergency shell";
    }
    elsif (match_has_tag('emergency-mode')) {
        type_password;
        send_key 'ret';
        script_run "journalctl --no-pager > /dev/$serialdev";
        die "hit emergency mode";
    }
}

=head2 service_action

  service_action($service_name [, {type => ['$unit_type', ...] [,action => ['$service_action', ...]]}]);

Control systemd services. C<type> may be set to service, socket, ... and C<$action>
to start, stop, ... Default action is to 'stop' $service_name.service unit file.

Example:

  service_action('dbus', {type => ['socket', 'service'], action => ['unmask', 'start']});

=cut
sub service_action {
    my ($name, $args) = @_;

    # default action is to 'stop' ${service_name}.service unit file
    my @types   = $args->{type}   ? @{$args->{type}}   : 'service';
    my @actions = $args->{action} ? @{$args->{action}} : 'stop';
    foreach my $action (@actions) {
        foreach my $type (@types) {
            systemctl "$action $name.$type";
        }
    }
}

=head2 install_all_from_repo
will install all packages in repo defined by C<INSTALL_ALL_REPO> variable
with ability to exclude some of them by using C<INSTALL_ALL_EXCEPT> which suppose to contain
space separated list of packages
=cut
sub install_all_from_repo {
    my $repo         = get_required_var('INSTALL_ALL_REPO');
    my $grep_str     = "";
    my $hpc_excludes = "hpc-openqa-tools-devel openqa-ci-tools-devel .*openqa-tests";
    if (get_var('INSTALL_ALL_EXCEPT') or get_var('HPC')) {
        #spliting space separated list of packages into array to iterate over it
        my @packages_array = split(/ /, get_var('INSTALL_ALL_EXCEPT'));
        push @packages_array, split(/ /, $hpc_excludes) if get_var('HPC');
        $grep_str = '|grep -vE "(' . join('|', @packages_array) . ')$"';
    }
    my $exec_str = sprintf("zypper se -ur %s -t package | awk '{print \$2}' | sed '1,/|/d' %s | xargs zypper -n in", $repo, $grep_str);
    assert_script_run($exec_str, 900);
}

=head2 run_scripted_command_slow

    run_scripted_command_slow($cmd [, slow_type => <num>]);

Type slowly to run very long command in scripted way to avoid issue of 'key event queue full' (see poo#12250).
Pass optional slow_type key to control how slow to type the command.
Scripted very long command to shorten typing length.
Default slow_type is type_string_slow.

=cut

sub run_scripted_command_slow {
    my ($cmd, %args) = @_;
    my $suffix = hashed_string("SO$cmd");

    open(my $fh, '>', 'current_script');
    print $fh $cmd;
    close $fh;

    my $slow_type   = $args{slow_type} // 1;
    my $curl_script = "curl -f -v " . autoinst_url("/current_script") . " > /tmp/script$suffix.sh" . " ; echo curl-\$? > /dev/$testapi::serialdev\n";
    my $exec_script = "/bin/bash -x /tmp/script$suffix.sh" . " ; echo script$suffix-\$? > /dev/$testapi::serialdev\n";
    if ($slow_type == 1) {
        type_string_slow $curl_script;
        wait_serial "curl-0" || die "Command $curl_script died";
        type_string_slow $exec_script;
        wait_serial "script$suffix-0" || die "Command $exec_script died";
    }
    elsif ($slow_type == 2) {
        type_string_very_slow $curl_script;
        wait_serial "curl-0" || die "Command $curl_script died";
        type_string_very_slow $exec_script;
        wait_serial "script$suffix-0" || die "Command $exec_script died";
    }
    elsif ($slow_type == 3) {
        type_string $curl_script, wait_screen_change => 1;
        wait_serial "curl-0" || die "Command $curl_script died";
        type_string $exec_script, wait_screen_change => 1;
        wait_serial "script$suffix-0" || die "Command $exec_script died";
    }
    clear_console;
}


=head2 get_root_console_tty
Returns tty number used designed to be used for root-console.
When console is not yet initialized, we cannot get it from arguments.
Since SLE 15 gdm is running on tty2, so we change behaviour for it and
openSUSE distris.
=cut
sub get_root_console_tty {
    return (sle_version_at_least('15') && !is_caasp) ? 6 : 2;
}

=head2 get_x11_console_tty
Returns tty number used designed to be used for X
Since SLE 15 gdm is always running on tty7, currently the main GUI session
is running on tty2 by default. see also: bsc#1054782
=cut
sub get_x11_console_tty {
    my $new_gdm
      = !is_sle('<15')
      && !(is_leap && !leap_version_at_least('15.0'))
      && !is_sle12_hdd_in_upgrade
      && !is_caasp
      && !get_var('VERSION_LAYERED');
    return (check_var('DESKTOP', 'gnome') && get_var('NOAUTOLOGIN') && $new_gdm) ? 2 : 7;
}

=head2 setup_static_network
Configure static IP on SUT with setting up DNS and default GW.
Also doing test ping to 10.0.2.2 to check that network is alive
=cut
sub setup_static_network {
    my ($self, $ip) = @_;
    configure_default_gateway();
    configure_static_ip($ip);
    configure_static_dns(get_host_resolv_conf());

    # check if gateway is reachable
    assert_script_run "ping -c 1 10.0.2.2 || journalctl -b --no-pager > /dev/$serialdev";
}

=head2  arrays_differ
Comparing two arrays passed by reference. Return 1 if arrays has symmetric difference
and 0 otherwise.
=cut
sub arrays_differ {
    my ($array1_ref, $array2_ref) = @_;
    my @array1 = @{$array1_ref};
    my @array2 = @{$array2_ref};
    return 1 if scalar(@array1) != scalar(@array2);
    foreach my $item (@array1) {
        return 1 if !grep($item eq $_, @array2);
    }
    return 0;
}

=head2 ensure_serialdev_permissions
Grant user permission to access serial port immediately as well as persisting
over reboots. Used to ensure that testapi calls like script_run work for the
test user as well as root.
=cut
sub ensure_serialdev_permissions {
    my ($self) = @_;
    # ownership has effect immediately, group change is for effect after
    # reboot an alternative https://superuser.com/a/609141/327890 would need
    # handling of optional sudo password prompt within the exec
    # Need backwards support for SLES11-SP4 here, the command "gpasswd" and "stat" are only available with SLES-12 at least.
    if (is_sle && check_var('VERSION', '11-SP4')) {
        assert_script_run "chown $username /dev/$serialdev";
    }
    else {
        assert_script_run "chown $testapi::username /dev/$testapi::serialdev && gpasswd -a $testapi::username \$(stat -c %G /dev/$testapi::serialdev)";
    }
}

1;

# vim: sw=4 et
