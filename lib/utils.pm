# Copyright (C) 2015-2017 SUSE LLC
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

our @EXPORT = qw(
  check_console_font
  clear_console
  is_casp
  is_gnome_next
  is_jeos
  is_krypton_argon
  is_kde_live
  is_leap
  is_tumbleweed
  select_kernel
  type_string_slow
  type_string_very_slow
  unlock_if_encrypted
  prepare_system_reboot
  get_netboot_mirror
  zypper_call
  fully_patch_system
  minimal_patch_system
  workaround_type_encrypted_passphrase
  ensure_unlocked_desktop
  leap_version_at_least
  sle_version_at_least
  install_to_other_at_least
  ensure_fullscreen
  ensure_shim_import
  reboot_x11
  poweroff_x11
  power_action
  assert_shutdown_and_restore_system
  assert_screen_with_soft_timeout
  is_desktop_installed
  pkcon_quit
  addon_decline_license
  addon_license
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
);


# USB kbd in raw mode is rather slow and QEMU only buffers 16 bytes, so
# we need to type very slowly to not lose keypresses.

# arbitrary slow typing speed for bootloader prompt when not yet scrolling
use constant SLOW_TYPING_SPEED => 13;

# type even slower towards the end to ensure no keybuffer overflow even
# when scrolling within the boot command line to prevent character
# mangling
use constant VERY_SLOW_TYPING_SPEED => 4;

sub unlock_if_encrypted {
    my (%args) = @_;
    $args{check_typed_password} //= 0;

    return unless get_var("ENCRYPT");

    if (check_var('ARCH', 's390x') && check_var('BACKEND', 'svirt')) {
        my $password = $testapi::password;
        my $svirt    = select_console('svirt');
        my $name     = $svirt->name;
        $svirt->suspend;
        type_string "export pty=`virsh dumpxml $name | grep \"console type=\" | sed \"s/'/ /g\" | awk '{ print \$5 }'`\n";
        type_string "echo \$pty\n";
        $svirt->resume;

        # enter passphrase twice (before grub and after grub) if full disk is encrypted
        if (get_var('FULL_LVM_ENCRYPT')) {
            wait_serial("Please enter passphrase for disk.*", 100);
            type_string "echo $password > \$pty\n";
        }
        wait_serial("Please enter passphrase for disk.*", 100);
        type_string "echo $password > \$pty\n";
    }
    else {
        assert_screen("encrypted-disk-password-prompt", 200);
        type_password;    # enter PW at boot
        save_screenshot;
        assert_screen 'encrypted_disk-typed_password' if $args{check_typed_password};
        send_key "ret";
    }
}

sub turn_off_kde_screensaver {
    x11_start_program("kcmshell5 screenlocker");
    assert_screen([qw(kde-screenlock-enabled screenlock-disabled)]);
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
sub prepare_system_reboot {
    if (check_var('BACKEND', 's390x')) {
        console('iucvconn')->kill_ssh;
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
    x11_start_program("$application $args{exec_param}");
    assert_screen("test-$application-started");
    send_key "alt-f4" unless $args{remain};
}

sub select_kernel {
    my $kernel = shift;

    assert_screen ['grub2', "grub2-$kernel-selected"], 100;
    if (match_has_tag "grub2-$kernel-selected") {    # if requested kernel is selected continue
        send_key 'ret';
    }
    else {                                           # else go to that kernel thru grub2 advanced options
        send_key_until_needlematch 'grub2-advanced-options', 'down';
        send_key 'ret';
        send_key_until_needlematch "grub2-$kernel-selected", 'down';
        send_key 'ret';
    }
    if (get_var('NOAUTOLOGIN')) {
        my $ret = assert_screen 'displaymanager', 200;
        mouse_hide();
        if (get_var('DM_NEEDS_USERNAME')) {
            type_string $username;
        }
        else {
            send_key 'ret';
            wait_idle;
        }
        type_password;
        send_key 'ret';
    }
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

sub is_jeos {
    return get_var('FLAVOR', '') =~ /^JeOS/;
}

sub is_krypton_argon {
    return get_var('FLAVOR') =~ /(Krypton|Argon)/;
}

sub is_kde_live {
    return get_var('FLAVOR') =~ /KDE-Live/;
}

sub is_gnome_next {
    return get_var('FLAVOR') =~ /Gnome-Live/;
}

# Check if distribution is CASP
# If argument is passed then FLAVOR has to match (universal VMX keyword)
sub is_casp {
    my $filter = shift;
    return 0 unless get_var('DISTRI') =~ /casp|kubic/;
    return 1 unless $filter;

    if ($filter eq 'DVD') {
        return get_var('FLAVOR') =~ /DVD/;    # DVD and Staging-?-DVD
    }
    elsif ($filter eq 'VMX') {
        return get_var('FLAVOR') !~ /DVD/;    # If not DVD it's VMX
    }
    else {
        return check_var('FLAVOR', $filter);    # Specific FLAVOR selector
    }
}

sub is_tumbleweed {
    # Tumbleweed and its stagings
    return 0 unless check_var('DISTRI', 'opensuse');
    return 1 if check_var('VERSION', 'Tumbleweed');
    return get_var('VERSION') =~ /^Staging:/;
}

sub is_leap {
    # Leap and its stagings
    return 0 unless check_var('DISTRI', 'opensuse');
    return 1 if get_var('VERSION', '') =~ /(?:[4-9][0-9]|[0-9]{3,})\.[0-9]/;
    return get_var('VERSION') =~ /^42:S/;
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

sub zypper_call {
    my $command          = shift;
    my %args             = @_;
    my $allow_exit_codes = $args{exitcode} || [0];
    my $timeout          = $args{timeout} || 700;
    my $log              = $args{log};

    my $str = hashed_string("ZN$command");
    my $redirect = is_serial_terminal() ? '' : " > /dev/$serialdev";

    if ($log) {
        script_run("zypper -n $command | tee /tmp/$log ; echo $str-\${PIPESTATUS}-$redirect", 0);
    }
    else {
        script_run("zypper -n $command; echo $str-\$?-$redirect", 0);
    }

    my $ret = wait_serial(qr/$str-\d+-/, $timeout);

    upload_logs("/tmp/$log") if $log;

    if ($ret) {
        my ($ret_code) = $ret =~ /$str-(\d+)/;
        die "'zypper -n $command' failed with code $ret_code" unless grep { $_ == $ret_code } @$allow_exit_codes;
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

sub workaround_type_encrypted_passphrase {
    if (
        get_var('FULL_LVM_ENCRYPT')
        || (check_var('ARCH', 'ppc64le')
            && (get_var('ENCRYPT') && !get_var('ENCRYPT_ACTIVATE_EXISTING') || get_var('ENCRYPT_FORCE_RECOMPUTE'))))
    {
        record_soft_failure 'workaround https://fate.suse.com/320901' if sle_version_at_least('12-SP4');
        unlock_if_encrypted;
    }
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
            type_password;
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

sub sle_version_at_least {
    my ($version, %args) = @_;
    my $version_variable = $args{version_variable} // 'VERSION';

    if ($version eq '12-SP1') {
        return !check_var($version_variable, '12');
    }

    if ($version eq '12-SP2') {
        return sle_version_at_least('12-SP1', version_variable => $version_variable)
          && !check_var($version_variable, '12-SP1');
    }

    if ($version eq '12-SP3') {
        return sle_version_at_least('12-SP2', version_variable => $version_variable)
          && !check_var($version_variable, '12-SP2');
    }

    if ($version eq '12-SP4') {
        return sle_version_at_least('12-SP3', version_variable => $version_variable)
          && !check_var($version_variable, '12-SP3');
    }

    if ($version eq '15') {
        return sle_version_at_least('12-SP4', version_variable => $version_variable)
          && !check_var($version_variable, '12-SP4');
    }
    die "unsupported SLE $version_variable $version in check";
}

# Method has to be extended similarly to sle_version_at_least once we know
# version naming convention as of now, we only add versions which we see in
# test. If one will use function and it dies, please extend function accordingly.
sub leap_version_at_least {
    my ($version, %args) = @_;
    # Verify if it's leap at all
    return 0 unless is_leap;

    my $version_variable = $args{version_variable} // 'VERSION';

    if ($version eq '42.2') {
        return check_var($version_variable, $version) || leap_version_at_least('42.3', version_variable => $version_variable);
    }

    if ($version eq '42.3') {
        return check_var($version_variable, $version);
    }
    # Die to point out that function has to be extended
    die "Unsupported Leap version $version_variable $version in check";
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

sub ensure_shim_import {
    my (%args) = @_;
    $args{tags} //= [qw(inst-bootmenu bootloader-shim-import-prompt)];
    assert_screen($args{tags}, 15);
    if (match_has_tag("bootloader-shim-import-prompt")) {
        send_key "down";
        send_key "ret";
    }
}

# VNC connection to SUT (the 'sut' console) is terminated on Xen via svirt
# backend and we have to re-connect *after* the restart, otherwise we end up
# with stalled VNC connection. The tricky part is to know *when* the system
# is already booting.
sub assert_shutdown_and_restore_system {
    my ($action) = @_;
    $action //= 'reboot';
    my $vnc_console = get_required_var('SVIRT_VNC_CONSOLE');
    console($vnc_console)->disable_vnc_stalls;
    assert_shutdown;
    if ($action eq 'reboot') {
        reset_consoles;
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
        wait_screen_change(sub { assert_and_click $mustmatch }, $wait_change);
        last unless check_screen($mustmatch, 0);
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
            assert_screen 'reboot-auth';
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
            prepare_system_reboot;

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
        send_key "ret";    # confirm shutdown

        if (get_var("SHUTDOWN_NEEDS_AUTH")) {
            assert_screen 'shutdown-auth', 15;
            type_password;

            # we need to kill all open ssh connections before the system shuts down
            prepare_system_reboot;
            send_key "ret";
        }
    }

    if (check_var("DESKTOP", "xfce")) {
        for (1 .. 5) {
            send_key "alt-f4";    # opens log out popup after all windows closed
        }
        wait_idle;
        assert_screen 'logoutdialog', 15;
        type_string "\t\t";       # select shutdown
        sleep 1;

        # assert_screen 'test-shutdown-1', 3;
        type_string "\n";
    }

    if (check_var("DESKTOP", "lxde")) {
        x11_start_program("lxsession-logout");    # opens logout dialog
        assert_screen "logoutdialog", 20;
        send_key "ret";
    }

    if (check_var("DESKTOP", "lxqt")) {
        x11_start_program("shutdown");            # opens logout dialog
        assert_screen "lxqt_logoutdialog", 20;
        send_key "ret";
    }
    if (check_var("DESKTOP", "enlightenment")) {
        send_key "ctrl-alt-delete";               # shutdown
        assert_screen 'logoutdialog', 15;
        assert_and_click 'enlightenment_shutdown_btn';
    }

    if (check_var('DESKTOP', 'awesome')) {
        assert_and_click 'awesome-menu-main';
        assert_and_click 'awesome-menu-system';
        assert_and_click 'awesome-menu-shutdown';
    }

    if (check_var("DESKTOP", "mate")) {
        x11_start_program("mate-session-save --shutdown-dialog");
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
    if (check_var('BACKEND', 'svirt')) {
        my $vnc_console = get_required_var('SVIRT_VNC_CONSOLE');
        console($vnc_console)->disable_vnc_stalls;
    }
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
    if (check_var('VIRSH_VMM_FAMILY', 'xen')) {
        assert_shutdown_and_restore_system($action);
    }
    else {
        assert_shutdown if $action eq 'poweroff';
        reset_consoles;
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

sub is_desktop_installed {
    return get_var("DESKTOP") !~ /textmode|minimalx/;
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

sub validatelr {
    my ($args) = @_;

    my $alias           = $args->{alias} || "";
    my $product         = $args->{product};
    my $product_channel = $args->{product_channel} || "";
    my $version         = $args->{version};
    if (get_var('ZDUP')) {
        $version = "";
    }
    if (get_var('FLAVOR') =~ m{SAP}) {
        $version .= "-SAP";
    }
    # Live patching and other modules are not per-service pack channel model,
    # so use major version to validate their repos
    if ($product eq 'SLE-Live') {
        $product = 'SLE-Live-Patching';
        $version = '12';
    }
    if ($product eq 'SLE-ASMM') {
        $product = 'SLE-Module-Adv-Systems-Management';
        $version = '12';
    }
    if ($product eq 'SLE-CONTM') {
        $product = 'SLE-Module-Containers';
        $version = '12';
    }
    if ($product eq 'SLE-HPCM') {
        $product = 'SLE-Module-HPC';
        $version = '12';
    }
    if ($product eq 'SLE-LGM') {
        $product = 'SLE-Module-Legacy';
        $version = '12';
    }
    if ($product eq 'SLE-PCM') {
        $product = 'SLE-Module-Public-Cloud';
        $version = '12';
    }
    if ($product eq 'SLE-TCM') {
        $product = 'SLE-Module-Toolchain';
        $version = '12';
    }
    if ($product eq 'SLE-WSM') {
        $product = 'SLE-Module-Web-Scripting';
        $version = '12';
    }
    if ($product eq 'SLE-PHUB') {
        $product = 'SUSE-PackageHub-';
    }
    # LTSS version is included in its product name
    # leave it as empty to match the regex
    if ($product =~ /LTSS/) {
        $version = '';
    }
    diag "validatelr alias:$alias product:$product cha:$product_channel version:$version";

    # Repo is checked for enabled/disabled state. If the information about the
    # expected state is not delivered to validatelr(), we use some heuristics to
    # determine the expected state: If the installation medium is a physical
    # medium and the system is registered to SCC the repo should be disabled
    # if the system is SLE 12 SP2 and later; enabled otherwise, see PR#11460 and
    # FATE#320494.
    my $scc_install_sle12sp2 = check_var('SCC_REGISTER', 'installation') and sle_version_at_least('12-SP2');
    my $enabled_repo;
    if ($args->{enabled_repo}) {
        $enabled_repo = $args->{enabled_repo};
    }
    # bsc#1012258, bsc#793709: USB repo is disabled as the USB stick will be
    # very likely removed from the system.
    elsif ($args->{uri} =~ m{(cd|dvd|hd):///.*usb-}) {
        $enabled_repo = 'No';
    }
    elsif ($args->{uri} =~ m{(cd|dvd|hd):///.*usbstick-}) {
        record_soft_failure 'boo#1019634 repo on USB medium is not disabled for "hd:///…scsi…usbstick"';
        $enabled_repo = 'Yes';
    }
    elsif ($args->{uri} =~ m{(cd|dvd|hd):///} and $scc_install_sle12sp2) {
        $enabled_repo = 'No';
    }
    else {
        $enabled_repo = 'Yes';
    }
    my $uri = $args->{uri};

    if ($product =~ /IBM-DLPAR-(Adv-Toolchain|SDK|utils)/) {
        my $cmd
          = "zypper lr --uri | awk -F \'|\' -v OFS=\' \' \'{ print \$3,\$4,\$NF }\' | tr -s \' \' | grep --color \"$product\[\[:space:\]\[:punct:\]\[:space:\]\]*$enabled_repo $uri\"";
        run_scripted_command_slow($cmd, slow_type => 2);
    }
    elsif (check_var('DISTRI', 'sle')) {
        # SLES12 does not have 'SLES12-Source-Pool' SCC channel
        unless (($version eq "12") and ($product_channel eq "Source-Pool")) {
            my $cmd
              = "zypper lr --uri | awk -F \'|\' -v OFS=\' \' \'{ print \$2,\$3,\$4,\$NF }\' | tr -s \' \' | grep --color \"$product$version\[\[:alnum:\]\[:punct:\]\]*-*$product_channel $product$version\[\[:alnum:\]\[:punct:\]\[:space:\]\]*-*$product_channel $enabled_repo $uri\"";
            run_scripted_command_slow($cmd, slow_type => 2);
        }
    }
}

sub validate_repos_sle {
    my ($version) = @_;
    script_run "clear";

    # On SLE we follow "SLE Channels Checking Table"
    # (https://wiki.microfocus.net/index.php?title=SLE12_SP2_Channels_Checking_Table)
    my (%h_addons, %h_addonurl, %h_scc_addons);
    my @addons_keys   = split(/,/, get_var('ADDONS',   ''));
    my @addonurl_keys = split(/,/, get_var('ADDONURL', ''));
    my $scc_addon_str = '';
    for my $scc_addon (split(/,/, get_var('SCC_ADDONS', ''))) {
        # The form of LTSS repos is different with other addons
        # For example: SLES12-LTSS-Updates
        if ($scc_addon eq 'ltss') {
            $scc_addon_str .= "SLES$version-" . uc($scc_addon) . ',';
            next;
        }
        $scc_addon =~ s/geo/ha-geo/ if ($scc_addon eq 'geo');
        $scc_addon_str .= "SLE-" . uc($scc_addon) . ',';
    }
    my @scc_addons_keys = split(/,/, $scc_addon_str);
    @h_addons{@addons_keys}         = ();
    @h_addonurl{@addonurl_keys}     = ();
    @h_scc_addons{@scc_addons_keys} = ();

    my $base_product;
    if (check_var('DISTRI', 'sle')) {
        $base_product = (get_var('FLAVOR') =~ m{Desktop-DVD}) ? 'SLED' : 'SLES';
    }

    # On Xen PV there are no CDs nor DVDs being emulated, "raw" HDD is used instead
    my $cd  = (check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux')) ? 'hd' : 'cd';
    my $dvd = (check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux')) ? 'hd' : 'dvd';

    # On system with ONLINE_MIGRATION/ZDUP variable set, we don't have SLE media
    # repository of VERSION N but N-1 (i.e. on SLES12-SP2 we have SLES12-SP1
    # repository. For the sake of sanity, the base product repo is not being
    # verified in such a scenario.
    if (!(get_var('ONLINE_MIGRATION') || get_var('ZDUP'))) {
        # This is where we verify base product repos for SLES, SLED, and HA
        my $uri = check_var('ARCH', 's390x') ? "ftp://" : "$cd:///";
        if (check_var('FLAVOR', 'Server-DVD')) {
            if (check_var("BACKEND", "ipmi") || check_var("BACKEND", "generalhw")) {
                $uri = "http[s]*://.*suse";
            }
            elsif (get_var('USBBOOT') && sle_version_at_least('12-SP3')) {
                $uri = "hd:///.*usb-";
            }
            elsif (get_var('USBBOOT') && sle_version_at_least('12-SP2')) {
                $uri = "hd:///.*usbstick";
            }
            validatelr({product => "SLES", uri => $uri, version => $version});
        }
        elsif (check_var('FLAVOR', 'SAP-DVD')) {
            validatelr({product => "SLE-", uri => $uri, version => $version});
        }
        elsif (check_var('FLAVOR', 'Server-DVD-HA')) {
            validatelr({product => "SLES", uri => $uri, version => $version});
            validatelr({product => 'SLE-*HA', uri => get_var('ADDONURL_HA') || "$dvd:///", version => $version});
            if (exists $h_addonurl{geo} || exists $h_addons{geo}) {
                validatelr({product => 'SLE-*HAGEO', uri => get_var('ADDONURL_GEO') || "$dvd:///", version => $version});
            }
            delete @h_addonurl{qw(ha geo)};
            delete @h_addons{qw(ha geo)};
        }
        elsif (check_var('FLAVOR', 'Desktop-DVD')) {
            # Note: verification of AMD (SLED12) and NVIDIA (SLED12, SP1, and SP2) repos is missing
            validatelr({product => "SLED", uri => $uri, version => $version});
        }
    }

    # URI Addons
    for my $addonurl_prod (keys %h_addonurl) {
        my $addonurl_tmp;
        if ($addonurl_prod eq "sdk") {
            $addonurl_tmp = $addonurl_prod;
        }
        else {
            $addonurl_tmp = "sle" . $addonurl_prod;
        }
        validatelr({product => uc $addonurl_tmp, uri => get_var("ADDONURL_" . uc $addonurl_prod), version => $version});
    }

    # DVD Addons; FATE#320494 (PR#11460): disable installation source after installation if we register system
    for my $addon (keys %h_addons) {
        if ($addon ne "sdk") {
            $addon = "sle" . $addon;
        }
        validatelr(
            {
                product      => uc $addon,
                enabled_repo => get_var('SCC_REGCODE_' . uc $addon) ? "No" : "Yes",
                uri          => "$dvd:///",
                version      => $version
            });
    }

    # Verify SLES, SLED, Addons and their online SCC sources, if SCC_REGISTER is enabled
    if (check_var('SCC_REGISTER', 'installation') && !get_var('ZDUP')) {
        my ($uri, $nvidia_uri, $we);

        # Set uri and nvidia uri for smt registration and others (scc, proxyscc)
        # For smt url variable, we have to use https to import smt server's certification
        # After registration, the uri of smt could be http
        if (get_var('SMT_URL')) {
            ($uri = get_var('SMT_URL')) =~ s/https:\/\///;
            $uri        = "http[s]*://" . $uri;
            $nvidia_uri = $uri;
        }
        else {
            $uri        = "http[s]*://.*suse";
            $nvidia_uri = "http[s]*://.*nvidia";
        }

        for my $scc_product ($base_product, keys %h_scc_addons) {
            # Skip PackageHub as being not part of modules to validate
            next if $scc_product eq 'SLE-PHUB';
            # there will be no nvidia repo when WE add-on was removed with MIGRATION_REMOVE_ADDONS
            my $addon_removed = uc get_var('MIGRATION_REMOVE_ADDONS', 'none');
            $we = 1 if ($scc_product eq 'SLE-WE' && $scc_product !~ /$addon_removed/);
            for my $product_channel ("Pool", "Updates", "Debuginfo-Pool", "Debuginfo-Updates", "Source-Pool") {
                # Toolchain module doesn't have Source-Pool channel
                next if (($scc_product eq 'SLE-TCM') && ($product_channel eq 'Source-Pool'));
                # LTSS doesn't have Pool, Debuginfo-Pool and Source-Pool channels
                next if (($scc_product =~ /LTSS/) && ($product_channel =~ /(|Debuginfo-|Source-)Pool/));
                # don't look for add-on that was removed with MIGRATION_REMOVE_ADDONS
                next if (get_var('ZYPPER_LR') && get_var('MIGRATION_INCONSISTENCY_DEACTIVATE') && $scc_product =~ /$addon_removed/);
                # IDU and IDS don't have channels, repo is checked below
                next if ($scc_product eq 'SLE-IDU' || $scc_product eq 'SLE-IDS');
                validatelr(
                    {
                        product         => $scc_product,
                        product_channel => $product_channel,
                        enabled_repo    => ($product_channel =~ m{(Debuginfo|Source)}) ? "No" : "Yes",
                        uri             => $uri,
                        version         => $version
                    });
            }
        }

        # IBM DLPAR repos check for ppc64le
        if (exists $h_scc_addons{'SLE-IDU'}) {
            validatelr(
                {
                    product      => 'IBM-DLPAR-utils',
                    enabled_repo => 'Yes',
                    uri          => 'http://public.dhe.ibm'
                });
        }
        if (exists $h_scc_addons{'SLE-IDS'}) {
            validatelr(
                {
                    product      => 'IBM-DLPAR-SDK',
                    enabled_repo => 'Yes',
                    uri          => 'http://public.dhe.ibm'
                });
            validatelr(
                {
                    product      => 'IBM-DLPAR-Adv-Toolchain',
                    enabled_repo => 'Yes',
                    uri          => 'http://ftp.unicamp.br'
                });
        }

        # Check nvidia repo if SLED or sle-we extension registered
        # For the name of product channel, sle12 uses NVIDIA, sle12sp1 and sp2 use nVidia
        # Consider migration, use regex to match nvidia whether in upper, lower or mixed
        # Skip check AMD/ATI repo since it would be removed from sled12 and sle-we-12, see bsc#984866
        if ($base_product eq "SLED" || $we) {
            validatelr(
                {
                    product         => "SLE-",
                    product_channel => 'GA-Desktop-[nN][vV][iI][dD][iI][aA]-Driver',
                    enabled_repo    => 'Yes',
                    uri             => $nvidia_uri,
                    version         => $version
                });
        }
    }

    # zdup upgrade repo verification
    # s390x can't use dvd media, only works with network repo
    if (get_var('ZDUP')) {
        my $uri;
        if (get_var('TEST') =~ m{zdup_offline} and !check_var('ARCH', 's390x')) {
            $uri = "$dvd:///";
        }
        else {
            $uri = "ftp://openqa.suse.de/SLE-";
        }
        validatelr(
            {
                product      => "repo1",
                enabled_repo => "Yes",
                uri          => $uri,
                version      => $version
            });
    }
}

sub validate_repos {
    my ($version) = @_;
    $version //= get_var('VERSION');

    assert_script_run "zypper lr | tee /dev/$serialdev", 180;
    script_run "clear";
    assert_script_run "zypper lr -d | tee /dev/$serialdev", 180;

    if (check_var('DISTRI', 'sle') and !get_var('STAGING') and sle_version_at_least('12-SP1')) {
        validate_repos_sle($version);
    }
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
    if (get_var('DM_NEEDS_USERNAME')) {
        type_string "$username\n";
    }
    if (check_var('DESKTOP', 'gnome') || (check_var('DESKTOP', 'lxde') && check_var('VERSION', '42.1'))) {
        # DMs in condition above have to select user
        send_key 'ret';
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
        x11_start_program("$command");    # opens logout dialog
        assert_screen 'logoutdialog' unless check_var('DESKTOP', 'gnome');
    }
    else {
        my $key = check_var('DESKTOP', 'xfce') ? 'alt-f4' : 'ctrl-alt-delete';
        send_key_until_needlematch 'logoutdialog', "$key";    # opens logout dialog
    }
    assert_and_click 'logout-button';                         # press logout
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
            assert_script_run "systemctl $action $name.$type";
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
        wait_serial "curl-0";
        type_string_slow $exec_script;
        wait_serial "script$suffix-0";
    }
    elsif ($slow_type == 2) {
        type_string_very_slow $curl_script;
        wait_serial "curl-0";
        type_string_very_slow $exec_script;
        wait_serial "script$suffix-0";
    }
    elsif ($slow_type == 3) {
        type_string $curl_script, wait_screen_change => 1;
        wait_serial "curl-0";
        type_string $exec_script, wait_screen_change => 1;
        wait_serial "script$suffix-0";
    }
    clear_console;
}

1;

# vim: sw=4 et
