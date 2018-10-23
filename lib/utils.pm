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
use lockapi 'mutex_wait';
use mm_network;
use version_utils qw(is_caasp is_leap is_sle is_sle12_hdd_in_upgrade sle_version_at_least is_storage_ng is_jeos);
use Mojo::UserAgent;

our @EXPORT = qw(
  check_console_font
  clear_console
  type_string_slow
  type_string_very_slow
  save_svirt_pty
  type_line_svirt
  integration_services_check
  unlock_if_encrypted
  get_netboot_mirror
  zypper_call
  fully_patch_system
  minimal_patch_system
  workaround_type_encrypted_passphrase
  select_user_gnome
  ensure_unlocked_desktop
  install_to_other_at_least
  is_bridged_networking
  set_bridged_networking
  ensure_fullscreen
  assert_screen_with_soft_timeout
  pkcon_quit
  systemctl
  addon_decline_license
  addon_license
  addon_products_is_applicable
  noupdatestep_is_applicable
  turn_off_kde_screensaver
  turn_off_gnome_screensaver
  random_string
  handle_login
  handle_logout
  handle_relogin
  handle_emergency
  handle_grub_zvm
  service_action
  assert_gui_app
  run_scripted_command_slow
  get_root_console_tty
  get_x11_console_tty
  OPENQA_FTP_URL
  arrays_differ
  ensure_serialdev_permissions
  assert_and_click_until_screen_change
  exec_and_insert_password
  shorten_url
  reconnect_s390
  set_hostname
  zypper_ar
  show_tasks_in_blocked_state
);


# USB kbd in raw mode is rather slow and QEMU only buffers 16 bytes, so
# we need to type very slowly to not lose keypresses.

# arbitrary slow typing speed for bootloader prompt when not yet scrolling
use constant SLOW_TYPING_SPEED => 13;

# type even slower towards the end to ensure no keybuffer overflow even
# when scrolling within the boot command line to prevent character
# mangling
use constant VERY_SLOW_TYPING_SPEED => 4;

# Due to missed keys on boot parameters on Leap 42.3 workers, try with even
# slower typing speed until they are upgraded to Leap 15.0
# https://progress.opensuse.org/issues/40670
use constant EXTREME_SLOW_TYPING_SPEED => 2;

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

sub unlock_zvm_disk {
    my ($console) = @_;
    eval { console('x3270')->expect_3270(output_delim => 'Please enter passphrase', timeout => 30) };
    if ($@) {
        diag 'No passphrase asked, continuing';
    }
    else {
        $console->sequence_3270("String(\"$testapi::password\")", "ENTER");
        diag 'Passphrase entered';
    }

}

sub handle_grub_zvm {
    my ($console) = @_;
    eval { $console->expect_3270(output_delim => 'GNU GRUB', timeout => 60); };
    if ($@) {
        diag 'Could not find GRUB screen, continuing nevertheless, trying to boot';
    }
    else {
        $console->sequence_3270("ENTER", "ENTER", "ENTER", "ENTER");
    }
}

=head2 integration_services_check
Make sure integration services (e.g. kernel modules, utilities, services)
are present and in working condition. Just Hyper-V for now.
=cut
sub integration_services_check {
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        # Host-side of Integration Services
        my $vmname       = console('svirt')->name;
        my $ips_host_pov = console('svirt')
          ->get_cmd_output('powershell -Command "Get-VM ' . $vmname . ' | Get-VMNetworkAdapter | Format-Table -HideTableHeaders IPAddresses"');
        $ips_host_pov =~ m/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/;
        $ips_host_pov = $1;
        my $ips_guest_pov = script_output("ip address show up scope global | awk '/inet/ { print \$2 }' | sed 's|/.*||' | tr -d '\\n'");
        record_info('IP (host)',  $ips_host_pov);
        record_info('IP (guest)', $ips_guest_pov);
        die "ips_host_pov=<$ips_host_pov> ips_guest_pov=<$ips_guest_pov>" if $ips_host_pov ne $ips_guest_pov;
        die 'Client nor host see IP address of the VM' unless $ips_host_pov;
        # Guest-side of Integration Services
        assert_script_run('rpmquery hyper-v');
        assert_script_run('rpmverify hyper-v');
        my $base = is_jeos() ? '-base' : '';
        for my $module (qw(utils netvsc storvsc vmbus)) {
            assert_script_run("rpmquery -l kernel-default$base | grep hv_${module}.ko");
            assert_script_run("modinfo hv_$module");
            assert_script_run("lsmod | grep hv_$module");
        }
        # 'hv_balloon' need not to be loaded
        assert_script_run('modinfo hv_balloon');
        systemctl('is-active hv_kvp_daemon.service');
        systemctl('is-active hv_vss_daemon.service');
        # 'Guest Services' are not enabled by default on our VMs
        assert_script_run('systemctl list-unit-files | grep hv_fcopy_daemon.service');
    }
}

sub unlock_if_encrypted {
    my (%args) = @_;
    $args{check_typed_password} //= 0;

    return unless get_var("ENCRYPT");

    if (get_var('S390_ZKVM')) {
        my $password = $testapi::password;
        select_console('svirt');

        # enter passphrase twice (before grub and after grub) if full disk is encrypted
        if (get_var('FULL_LVM_ENCRYPT')) {
            wait_serial("Please enter passphrase for disk.*", 100);
            type_line_svirt "$password";
        }
        wait_serial('GNU GRUB') || diag 'Could not find GRUB screen, continuing nevertheless, trying to boot';
        type_line_svirt '', expect => "Please enter passphrase for disk.*", timeout => 100, fail_message => 'Could not find "enter passphrase" prompt';
        type_line_svirt "$password";
    }    # Handle zVM scenario
    elsif (check_var('BACKEND', 's390x')) {
        my $console = console('x3270');
        # Enter password before GRUB if boot is encrypted
        # Boot partition is always encrypted, if not using expert partitioner with
        # separate unencrypted boot
        unlock_zvm_disk($console) unless get_var('UNENCRYPTED_BOOT');
        handle_grub_zvm($console);
        unlock_zvm_disk($console);
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
    send_key('alt-o');
    assert_screen 'generic-desktop';
}

=head2 turn_off_gnome_screensaver

  turn_off_gnome_screensaver()

Disable screensaver in gnome. To be called from a command prompt, for example an xterm window.

=cut
sub turn_off_gnome_screensaver {
    script_run 'gsettings set org.gnome.desktop.session idle-delay 0';
}


# 'ctrl-l' does not get queued up in buffer. If this happens to fast, the
# screen would not be cleared
sub clear_console {
    type_string "clear\n";
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
    my $params = $args{exec_param} ? " $args{exec_param}" : '';
    x11_start_program($application . $params, target_match => "test-$application-started");
    send_key "alt-f4" unless $args{remain};
}

# 13.2, Leap 42.1, SLE12 GA&SP1 have problems with setting up the
# console font, we need to call systemd-vconsole-setup to workaround
# that
sub check_console_font {
    # Does not make sense on ssh-based consoles
    return if (check_var('BACKEND', 'spvm')) || (check_var('BACKEND', 'ipmi'));
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

    my $printer = $log ? "| tee /tmp/$log" : $dumb_term ? '| cat' : '';
    die 'Exit code is from PIPESTATUS[0], not grep' if $command =~ /^((?!`).)*\| ?grep/;

    # Retrying workarounds
    my $ret;
    for (1 .. 3) {
        $ret = script_run("zypper -n $command $printer; ( exit \${PIPESTATUS[0]} )", $timeout);
        die "zypper did not finish in $timeout seconds" unless defined($ret);
        if ($ret == 4) {
            if (script_run('grep "Error code.*502" /var/log/zypper.log') == 0) {
                record_soft_failure 'Retrying because of error 502 - bsc#1070851';
                next;
            }
        }
        last;
    }
    upload_logs("/tmp/$log") if $log;

    unless (grep { $_ == $ret } @$allow_exit_codes) {
        upload_logs('/var/log/zypper.log');
        die "'zypper -n $command' failed with code $ret";
    }
    return $ret;
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

# Handle the case when user is not selected, on gnome
sub select_user_gnome {
    my ($myuser) = @_;
    $myuser //= $username;
    assert_screen [qw(displaymanager-user-selected displaymanager-user-notselected)];
    if (match_has_tag('displaymanager-user-notselected')) {
        assert_and_click "displaymanager-$myuser";
        record_soft_failure 'bsc#1086425- user account not selected by default, have to use mouse to login';
    }
    elsif (match_has_tag('displaymanager-user-selected')) {
        send_key 'ret';
    }
}

# if stay under tty console for long time, then check
# screen lock is necessary when switch back to x11
# all possible options should be handled within loop to get unlocked desktop
sub ensure_unlocked_desktop {
    my $counter = 10;
    while ($counter--) {
        assert_screen [qw(displaymanager displaymanager-password-prompt generic-desktop screenlock screenlock-password)], no_wait => 1;
        if (match_has_tag 'displaymanager') {
            if (check_var('DESKTOP', 'minimalx')) {
                type_string "$username";
                save_screenshot;
            }
            if (!check_var('DESKTOP', 'gnome') || (is_sle('<15') || is_leap('<15.0'))) {
                send_key 'ret';
            }
            # On gnome, user may not be selected and using 'ret' is not enough in this case
            else {
                select_user_gnome($username);
            }
        }
        if ((match_has_tag 'displaymanager-password-prompt') || (match_has_tag 'screenlock-password')) {
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
                if (check_screen 'desktop-runner', 30) {
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
            unless (get_var('DESKTOP', '') =~ m/gnome/ && check_screen('blackscreen')) {
                # Only xscreensaver has a blackscreen as screenlock but gnome might
                # show a black screen here as a transient screen due to switch to x11.
                # Pressing 'esc' in this case will break the user selection by pressing 'ret'.
                wait_screen_change {
                    send_key 'esc';    # end screenlock
                };
            }
        }
        wait_still_screen 2;           # slow down loop
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
    return get_var('BRIDGED_NETWORKING');
}

sub set_bridged_networking {
    my $ret = 0;
    if (check_var('BACKEND', 'svirt') and !check_var('ARCH', 's390x')) {
        my $vmm_family = get_required_var('VIRSH_VMM_FAMILY');
        $ret = ($vmm_family =~ /xen|vmware|hyperv/);
    }
    # Some needles match hostname which we can't set permanently with bridge.
    set_var('BRIDGED_NETWORKING', 1) if $ret;
}

=head2 set_hostname

    set_hostname($hostname);

Setting hostname according input parameter using hostnamectl.
Calling I<reload-or-restart> to make sure that network stack will propogate
hostname into DHCP/DNS

if you change hostname using C<hostnamectl set-hostname>, then C<hostname -f>
will fail with I<hostname: Name or service not known> also DHCP/DNS don't know
about the changed hostname, you need to send a new DHCP request to update
dynamic DNS yast2-network module does
C<NetworkService.ReloadOrRestart if Stage.normal || !Linuxrc.usessh>
if hostname is changed via C<yast2 lan>
=cut
sub set_hostname {
    my ($hostname) = @_;
    assert_script_run "hostnamectl set-hostname $hostname";
    assert_script_run "hostnamectl status|grep $hostname";
    assert_script_run "hostname|grep $hostname";
    systemctl 'status network.service';
    save_screenshot;
    assert_script_run "if systemctl -q is-active network.service; then systemctl reload-or-restart network.service; fi";
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
            # license on SLE15+ is shown only once during registration bsc#1057223
            # don't expect license if addon was already registered via SCC and license already viewed
            if (sle_version_at_least('15') && check_var('SCC_REGISTER', 'installation') && get_var('SCC_ADDONS') =~ /$addon/ && !check_screen \@tags) {
                return 1;
            }
            assert_screen \@tags;
            if (match_has_tag('import-untrusted-gpg-key')) {
                record_info 'untrusted gpg key', "Trusting untrusted GPG key", result => 'softfail';
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

=head2 handle_login

  handle_login($myuser, $user_selected);

Log the user in using the displaymanager.
When C<$myuser> is set, this user will be used for login.
Otherwise the function will default to C<$username>.
For displaymanagers (like gnome) where the user needs to be selected
from a menu C<$user_selected> tells the function that the desired
user has already been selected before this function was called.

Example:

  handle_login('user1', 1);

=cut
sub handle_login {
    my ($myuser, $user_selected) = @_;
    $myuser //= $username;
    $user_selected //= 0;

    assert_screen 'displaymanager', 90;    # wait for DM, then try to login
    wait_still_screen;
    if (get_var('ROOTONLY')) {
        if (check_screen 'displaymanager-username-notlisted', 10) {
            record_soft_failure 'bgo#731320/boo#1047262 "not listed" Login screen for root user is not intuitive';
            assert_and_click 'displaymanager-username-notlisted';
            wait_still_screen 3;
        }
        type_string "root\n";
    }
    elsif (match_has_tag('displaymanager-user-prompt') || get_var('DM_NEEDS_USERNAME')) {
        type_string "$myuser\n";
    }
    elsif (check_var('DESKTOP', 'gnome')) {
        if ($user_selected || (is_sle('<15') || is_leap('<15.0'))) {
            send_key 'ret';
        }
        # DMs in condition above have to select user
        else {
            select_user_gnome($myuser);
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

sub handle_relogin {
    handle_logout;
    handle_login;
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
openSUSE distris, except for Xen PV (bsc#1086243).
=cut
sub get_root_console_tty {
    return (sle_version_at_least('15') && !is_caasp && !check_var('VIRSH_VMM_TYPE', 'linux')) ? 6 : 2;
}

=head2 get_x11_console_tty
Returns tty number used designed to be used for X.
Since SLE 15 gdm is always running on tty7, currently the main GUI session
is running on tty2 by default, except for Xen PV (bsc#1086243).
See also: bsc#1054782
=cut
sub get_x11_console_tty {
    my $new_gdm
      = !is_sle('<15')
      && !is_leap('<15.0')
      && !is_caasp
      && !check_var('VIRSH_VMM_TYPE', 'linux')
      && !get_var('VERSION_LAYERED');
    return (check_var('DESKTOP', 'gnome') && get_var('NOAUTOLOGIN') && $new_gdm) ? 2 : 7;
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

=head2 exec_and_insert_password

    exec_and_insert_password($cmd);

 1. Execute a command that ask for a password
 2. Detects password prompt
 3. Insert password and hits enter

=cut
sub exec_and_insert_password {
    my ($cmd) = @_;
    my $hashed_cmd = hashed_string("SR$cmd");
    wait_serial(serial_terminal::serial_term_prompt(), undef, 0, no_regex => 1) if is_serial_terminal();
    # We need to clear the console to correctly catch the password needle if needed
    clear_console if !is_serial_terminal();
    type_string "$cmd";
    if (is_serial_terminal()) {
        type_string " ; echo $hashed_cmd-\$?-\n";
        wait_serial(qr/Password:\s*$/i);
    }
    else {
        send_key 'ret';
        assert_screen('password-prompt', 60);
    }
    type_password;
    send_key "ret";

    if (is_serial_terminal()) {
        wait_serial(qr/$hashed_cmd-\d+-/);
    }
    else {
        wait_still_screen(stilltime => 10);
    }
}

=head2 shorten_url
Shotren url via schort(s.qa.suse.de)
This is mainly used for autoyast url shorten to avoid limit of x3270 xedit
=cut
sub shorten_url {
    my ($url, %args) = @_;
    $args{wishid} //= '';

    my $ua = Mojo::UserAgent->new;

    my $tx = $ua->post('s.qa.suse.de' => form => {url => $url, wishId => $args{wishid}});
    if (my $res = $tx->success) {
        return $res->body;
    }
    else {
        my $err = $tx->error;
        die "Shorten url got $err->{code} response: $err->{message}" if $err->{code};
        die "Connection error when shorten url: $err->{message}";
    }
}

sub _handle_login_not_found {
    my ($str) = @_;
    record_info 'Investigation', 'Expected welcome message not found, investigating bootup log content: ' . $str;
    diag 'Checking for bootloader';
    record_info 'grub not found', 'WARNING: bootloader grub menue not found' unless $str =~ /GNU GRUB/;
    diag 'Checking for ssh daemon';
    record_info 'ssh not found', 'WARNING: ssh daemon in SUT is not available' unless $str =~ /Started OpenSSH Daemon/;
    diag 'Checking for any welcome message';
    die 'no welcome message found, system seems to have never passed the bootloader (stuck or not enough waiting time)' unless $str =~ /Welcome to/;
    diag 'Checking login target reached';
    record_info 'No login target' unless $str =~ /Reached target Login Prompts/;
    diag 'Checking for login prompt';
    record_info 'No login prompt' unless $str =~ /login:/;
    diag 'Checking for known failure';
    return record_soft_failure 'bsc#1040606 - incomplete message when LeanOS is implicitly selected instead of SLES'
      if $str =~ /Welcome to SUSE Linux Enterprise 15/;
    my $error_details = $str;
    if (check_var('BACKEND', 's390x')) {
        diag 'Trying to look for "blocked tasks" with magic sysrq';
        console('x3270')->sequence_3270("String(\"^-w\\n\")");
        my $r = console('x3270')->expect_3270(buffer_full => qr/(MORE\.\.\.|HOLDING)/);
        save_screenshot;
        $error_details = join("\n", @$r);
    }

    die "unknown error, system couldn't boot. Detailed bootup log:\n$error_details";
}

=head2 reconnect_s390
After each reboot we have to reconnect to s390 host
=cut
sub reconnect_s390 {
    my (%args) = @_;
    $args{timeout} //= 300;

    my $login_ready = qr/Welcome to SUSE Linux Enterprise Server.*\(s390x\)/;
    console('installation')->disable_vnc_stalls;

    # different behaviour for z/VM and z/KVM
    if (check_var('BACKEND', 's390x')) {
        my $console = console('x3270');
        # grub is handled in unlock_if_encrypted unless affected by bsc#993247 or https://fate.suse.com/321208
        handle_grub_zvm($console) if (!get_var('ENCRYPT') || get_var('ENCRYPT_ACTIVATE_EXISTING') && !get_var('ENCRYPT_FORCE_RECOMPUTE'));
        my $r;
        eval { $r = console('x3270')->expect_3270(output_delim => $login_ready, timeout => $args{timeout}); };
        if ($@) {
            my $ret = $@;
            _handle_login_not_found($ret);
        }
        reset_consoles;

        # reconnect the ssh for serial grab
        select_console('iucvconn');
    }
    else {
        # In case of encrypted partition, the GRUB screen check is implemented in 'unlock_if_encrypted' module
        if (get_var('ENCRYPT')) {
            wait_serial($login_ready) || diag 'Could not find GRUB screen, continuing nevertheless, trying to boot';
        }
        else {
            wait_serial('GNU GRUB') || diag 'Could not find GRUB screen, continuing nevertheless, trying to boot';
            select_console('svirt');
            save_svirt_pty;
            type_line_svirt '', expect => $login_ready, timeout => $args{timeout}, fail_message => 'Could not find login prompt';
        }
    }

    # SLE >= 15 does not offer auto-started VNC server in SUT, only login prompt as in textmode
    if (!check_var('DESKTOP', 'textmode') && !sle_version_at_least('15')) {
        select_console('x11', await_console => 0);
    }
}

sub zypper_ar {
    my ($url, $name) = @_;

    zypper_call("ar $url $name",                           dumb_term => 1);
    zypper_call("--gpg-auto-import-keys ref --repo $name", dumb_term => 1);
}

sub show_tasks_in_blocked_state {
    # sending sysrqs doesn't work for hyperv
    if (!check_var('MACHINE', 'svirt-hyperv')) {
        send_key 'alt-sysrq-w';
        # info will be sent to serial tty
        wait_serial('SysRq : Show Blocked State', 1);
    }
}

1;
