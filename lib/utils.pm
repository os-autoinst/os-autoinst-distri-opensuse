# Copyright (C) 2015-2020 SUSE LLC
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
use warnings;
use testapi qw(is_serial_terminal :DEFAULT);
use lockapi 'mutex_wait';
use mm_network;
use version_utils qw(is_caasp is_leap is_sle is_sle12_hdd_in_upgrade is_storage_ng is_jeos);
use Utils::Architectures qw(is_aarch64 is_ppc64le);
use Utils::Systemd qw(systemctl disable_and_stop_service);
use Mojo::UserAgent;

our @EXPORT = qw(
  check_console_font
  clear_console
  type_string_slow
  type_string_very_slow
  type_string_slow_extended
  save_svirt_pty
  type_line_svirt
  integration_services_check
  integration_services_check_ip
  unlock_if_encrypted
  get_netboot_mirror
  zypper_call
  zypper_enable_install_dvd
  zypper_ar
  fully_patch_system
  handle_patch_11sp4_zvm
  ssh_fully_patch_system
  minimal_patch_system
  zypper_search
  workaround_type_encrypted_passphrase
  is_boot_encrypted
  is_bridged_networking
  set_bridged_networking
  assert_screen_with_soft_timeout
  pkcon_quit
  systemctl
  addon_decline_license
  addon_license
  addon_products_is_applicable
  noupdatestep_is_applicable
  installwithaddonrepos_is_applicable
  random_string
  handle_emergency
  handle_grub_zvm
  handle_untrusted_gpg_key
  service_action
  assert_gui_app
  run_scripted_command_slow
  get_root_console_tty
  get_x11_console_tty
  OPENQA_FTP_URL
  arrays_differ
  arrays_subset
  ensure_serialdev_permissions
  assert_and_click_until_screen_change
  exec_and_insert_password
  shorten_url
  reconnect_mgmt_console
  set_hostname
  show_tasks_in_blocked_state
  svirt_host_basedir
  prepare_ssh_localhost_key_login
  disable_serial_getty
  script_retry
  script_run_interactive
  create_btrfs_subvolume
  file_content_replace
);

=head1 SYNOPSIS

Main file for all kind of functions
=cut

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

=head2 save_svirt_pty

 save_svirt_pty();

Save the pty device within the svirt shell session so that we can refer to the
correct pty pointing to the first tty, e.g. for password entry for encrypted
partitions and rewriting the network definition of zKVM instances.

Does B<not> work on B<Hyper-V>.
=cut
sub save_svirt_pty {
    return if check_var('VIRSH_VMM_FAMILY', 'hyperv');
    my $name = console('svirt')->name;
    type_string "pty=`virsh dumpxml $name 2>/dev/null | grep \"console type=\" | sed \"s/'/ /g\" | awk '{ print \$5 }'`\n";
    type_string "echo \$pty\n";
}

=head2 type_line_svirt

 type_line_svirt($string [, expect => $expect] [, timeout => $timeout] [, fail_message => $fail_message]);

Sends C<$string> to the svirt terminal, waits up to C<$timeout> seconds
and expects C<$expect> to be returned on the terminal if C<$expect> is set.
If the expected text is not found, it will fail with C<$fail_message>.

=cut
sub type_line_svirt {
    my ($string, %args) = @_;
    type_string "echo $string > \$pty\n";
    if ($args{expect}) {
        wait_serial($args{expect}, $args{timeout}) || die $args{fail_message} // 'expected \'' . $args{expect} . '\' not found';
    }
}

=head2 unlock_zvm_disk

 unlock_zvm_disk($console);

Unlock the zvm disk if needed.
C<$console> should be set to C<console('x3270')>.
C<$testapi::password> will be used as password.

=cut
sub unlock_zvm_disk {
    my ($console) = @_;
    eval { $console->expect_3270(output_delim => 'Please enter passphrase', timeout => 30) };
    if ($@) {
        diag 'No passphrase asked, continuing';
    }
    else {
        $console->sequence_3270("String(\"$testapi::password\")", "ENTER");
        diag 'Passphrase entered';
    }

}

=head2 handle_grub_zvm

 handle_grub_zvm($console);

Make sure that grub was started and send four enter keys to boot the system.
C<$console> should be set to C<console('x3270')>.

TODO: Add support for GRUB_BOOT_NONDEFAULT, GRUB_SELECT_FIRST_MENU, GRUB_SELECT_SECOND_MENU,
see boot_grub_item()
=cut
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

=head2 handle_untrusted_gpg_key

 handle_untrusted_gpg_key();

This function is used during the installation.
Check if a previous needle match included the tag C<import-known-untrusted-gpg-key>.
If yes, import the key, otherwise don't.

=cut
sub handle_untrusted_gpg_key {
    if (match_has_tag('import-known-untrusted-gpg-key')) {
        record_info('Import', 'Known untrusted gpg key is imported');
        wait_screen_change { send_key 'alt-t' };    # import
    }
    else {
        record_info('Cancel import', 'Untrusted gpg key is NOT imported');
        wait_screen_change { send_key 'alt-c' };    # cancel
    }
}

=head2 integration_services_check_ip

 integration_services_check_ip();

Check that guest IP address that host and guest see is the same.
Die, if this is not the case.

=cut
sub integration_services_check_ip {
    # Workaround for poo#44771 "Can't call method "exec" on an undefined value"
    select_console('svirt');
    select_console('sut');
    # Host-side of Integration Services
    my $vmname = console('svirt')->name;
    my $ips_host_pov;
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        $ips_host_pov = console('svirt')->get_cmd_output(
            'powershell -Command "Get-VM ' . $vmname . ' | Get-VMNetworkAdapter | Format-Table -HideTableHeaders IPAddresses"');
    }
    elsif (check_var('VIRSH_VMM_FAMILY', 'vmware')) {
        $ips_host_pov = console('svirt')->get_cmd_output(
            "set -x; vmid=\$(vim-cmd vmsvc/getallvms | awk '/$vmname/ { print \$1 }');" .
              "if [ \$vmid ]; then vim-cmd vmsvc/get.guest \$vmid | awk '/ipAddress/ {print \$3}' " .
              "| head -n1 | sed -e 's/\"//g' | sed -e 's/,//g'; fi", {domain => 'sshVMwareServer'});
    }
    $ips_host_pov =~ m/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/;
    $ips_host_pov = $1;
    # Guest-side of Integration Services
    my $ips_guest_pov = script_output("default_iface=\$(awk '\$2 == 00000000 { print \$1 }' /proc/net/route); ip addr show dev \"\$default_iface\" | awk '\$1 == \"inet\" { sub(\"/.*\", \"\", \$2); print \$2 }'");
    record_info('IP (host)',  $ips_host_pov);
    record_info('IP (guest)', $ips_guest_pov);
    die "ips_host_pov=<$ips_host_pov> ips_guest_pov=<$ips_guest_pov>" if $ips_host_pov ne $ips_guest_pov;
    die 'Client nor host see IP address of the VM' unless $ips_host_pov;
}

=head2 integration_services_check

 integration_services_check();

Make sure integration services (e.g. kernel modules, utilities, services)
are present and in working condition.

=cut
sub integration_services_check {
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        integration_services_check_ip;
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
    elsif (check_var('VIRSH_VMM_FAMILY', 'vmware')) {
        integration_services_check_ip;
        assert_script_run('rpmquery open-vm-tools');
        assert_script_run('rpmquery open-vm-tools-desktop') unless check_var('DESKTOP', 'textmode');
        assert_script_run('modinfo vmw_vmci');
        systemctl('is-active vmtoolsd');
        systemctl('is-active vgauthd');
    }
}

=head2 unlock_if_encrypted

 unlock_if_encrypted([check_typed_password => $check_typed_password]);

Check whether the system under test has an encrypted partition and attempts to unlock it.
C<$check_typed_password> will default to C<0>.

=cut
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

=head2 clear_console

 clear_console();

C<ctrl-l> does not get queued up in buffer.
If this happens to fast, the screen would not be cleared.
So this function will simply type C<clear\n>.

=cut
sub clear_console {
    type_string "clear\n";
}

=head2 assert_gui_app

 assert_gui_app($application [, install => $install] [, exec_param => $exec_param] [, remain => $remain]);

assert_gui_app (optionally installs and) starts an application, checks it started
and closes it again. It's the most minimalistic way to test a GUI application

Mandatory parameter: C<application> (the name of the application).

Optional parameters are:

 install: boolean
     Does the application have to be installed first? Especially
     on live images where we want to ensure the disks are complete
     the parameter should not be set to true - otherwise we might
     mask the fact that the app is not on the media.

 exec_param: string
     When calling the application, pass this parameter on the command line.

 remain: boolean
     If set to true, do not close the application when tested it is
     running. This can be used if the application shall be tested further.

=cut
sub assert_gui_app {
    my ($application, %args) = @_;
    ensure_installed($application) if $args{install};
    my $params = $args{exec_param} ? " $args{exec_param}" : '';
    x11_start_program($application . $params, target_match => "test-$application-started");
    send_key "alt-f4" unless $args{remain};
}

=head2 check_console_font

 check_console_font();

Check the console font using a needle.

13.2, Leap 42.1, SLE12 GA&SP1 have problems with setting up the
console font, we need to call systemd-vconsole-setup to workaround
that.

=cut
sub check_console_font {
    # Does not make sense on ssh-based consoles
    return if get_var('BACKEND', '') =~ /ipmi|spvm|pvm_hmc/;
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

=head2 type_string_slow_extended

 type_string_slow_extended($string);

Enable additional arguments for nested calls of C<wait_still_screen>.

=cut
sub type_string_slow_extended {
    my ($string) = @_;
    type_string($string, max_interval => SLOW_TYPING_SPEED, wait_still_screen => 0.05, timeout => 5, similarity_level => 38);
}

=head2 type_string_slow

 type_string_slow($string);

Typing a string with C<SLOW_TYPING_SPEED> to avoid losing keys.

=cut
sub type_string_slow {
    my ($string) = @_;

    type_string $string, SLOW_TYPING_SPEED;
}

=head2 type_string_very_slow

 type_string_very_slow($string);

Typing a string even slower with C<VERY_SLOW_TYPING_SPEED>.

The bootloader prompt line is very delicate with typing especially when
scrolling. We are typing very slow but this could still pose problems
when the worker host is utilized so better wait until the string is
displayed before continuing
For the special winter grub screen with moving penguins
C<wait_still_screen> does not work so we just revert to sleeping a bit
instead of waiting for a still screen which is never happening. Sleeping
for 3 seconds is less waste of time than waiting for the
C<wait_still_screen> to timeout, especially because C<wait_still_screen> is
also scaled by C<TIMEOUT_SCALE> which we do not need here.

=cut
sub type_string_very_slow {
    my ($string) = @_;

    type_string $string, VERY_SLOW_TYPING_SPEED;

    if (get_var('WINTER_IS_THERE')) {
        sleep 3;
    }
    else {
        wait_still_screen(1, 3);
    }
}


=head2 get_netboot_mirror

 get_netboot_mirror();

Return the mirror URL eg from the C<MIRROR_HTTP> var if C<INSTALL_SOURCE> is set to C<http>.

=cut
sub get_netboot_mirror {
    my $m_protocol = get_var('INSTALL_SOURCE', 'http');
    return get_var('MIRROR_' . uc($m_protocol));
}

=head2 zypper_call

 zypper_call($command [, exitcode => $exitcode] [, timeout => $timeout] [, log => $log] [, dumb_term => $dumb_term]);

Function wrapping 'zypper -n' with allowed return code, timeout and logging facility.
First parammeter is required command, all others are named and provided as hash
for example:

 zypper_call("up", exitcode => [0,102,103], log => "zypper.log");

 # up        --> zypper -n up --> update system
 # exitcode  --> allowed return code values
 # log       --> capture log and store it in zypper.log
 # dumb_term --> pipes through cat if set to 1 and log is not set. This is a  workaround
 #               to get output without any ANSI characters in zypper before 1.14.1. See boo#1055315.

C<dumb_term> will default to C<is_serial_terminal()>.
=cut
sub zypper_call {
    my $command          = shift;
    my %args             = @_;
    my $allow_exit_codes = $args{exitcode} || [0];
    my $timeout          = $args{timeout} || 700;
    my $log              = $args{log};
    my $dumb_term        = $args{dumb_term} // is_serial_terminal;

    my $printer = $log ? "| tee /tmp/$log" : $dumb_term ? '| cat' : '';
    die 'Exit code is from PIPESTATUS[0], not grep' if $command =~ /^((?!`).)*\| ?grep/;

    # Retrying workarounds
    my $ret;
    for (1 .. 5) {
        $ret = script_run("zypper -n $command $printer; ( exit \${PIPESTATUS[0]} )", $timeout);
        die "zypper did not finish in $timeout seconds" unless defined($ret);
        if ($ret == 4) {
            if (script_run('grep "Error code.*502" /var/log/zypper.log') == 0) {
                die 'According to bsc#1070851 zypper should automatically retry internally. Bugfix missing for current product?';
            }
            next unless get_var('FLAVOR', '') =~ /-(Updates|Incidents)$/;
        }
        if (get_var('FLAVOR', '') =~ /-(Updates|Incidents)/ && ($ret == 4 || $ret == 8 || $ret == 105 || $ret == 106 || $ret == 139 || $ret == 141)) {
            if (script_run('grep "Exiting on SIGPIPE" /var/log/zypper.log') == 0) {
                record_soft_failure 'Zypper exiting on SIGPIPE received during package download bsc#1145521';
            }
            else {
                record_soft_failure 'Retry due to network problems poo#52319';
            }
            next;
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


=head2 zypper_enable_install_dvd

 zypper_enable_install_dvd();

Enables the install DVDs if they were used during the installation.

=cut
sub zypper_enable_install_dvd {
    # If DVD Packages is used we need to (re-)enable the local repos
    # see FATE#325541
    zypper_call('mr -e -l') if (is_sle('15+') and (get_var('ISO_1', '') =~ /SLE-.*-Packages-.*\.iso/ || check_var('FLAVOR', 'Full')));
    zypper_call 'ref';
}

=head2 zypper_ar

 zypper_ar($url, [ name => NAME ], [ priority => N ]);

Add repository (with C<zypper ar>) unless it's already repo C<$name> already added
and refresh repositories.

Options:

C<$name> alias for repository, optional
When used, additional check if repo not yet exists is done, and adding
only if it doesn't exist. Also zypper ref is run only on this repository.
NOTE: if not used, $url must be a URI pointing to a .repo file.

C<$no_gpg_check> pass --no-gpgcheck for repos with not valid GPG key, optional

C<$priority> set repo priority, optional

C<$params> other ar subcommand parameters, optional

Examples:

 zypper_ar('http://dist.nue.suse.com/ibs/QA:/Head/SLE-15-SP1', name => 'qa-head);
 zypper_ar('https://download.opensuse.org/repositories/devel:/kubic/openSUSE_Tumbleweed/devel:kubic.repo', no_gpg_check => 1, priority => 90);

=cut
sub zypper_ar {
    my ($url, %args) = @_;
    my $name         = $args{name}         // '';
    my $priority     = $args{priority}     // undef;
    my $params       = $args{params}       // '';
    my $no_gpg_check = $args{no_gpg_check} // '';

    $priority     = defined($priority) ? "-p $priority"  : "";
    $no_gpg_check = $no_gpg_check      ? "--no-gpgcheck" : "";
    my $cmd_ar  = "--gpg-auto-import-keys ar -f $priority $no_gpg_check $params $url";
    my $cmd_ref = "--gpg-auto-import-keys ref";

    # repo file
    if (!$name) {
        zypper_call($cmd_ar);
        return zypper_call($cmd_ref);
    }

    # URI alias
    my $out = script_output("LC_ALL=C zypper lr $name 2>&1", proceed_on_failure => 1);
    if ($out =~ /Repository.*$name.*not found/i) {
        zypper_call("$cmd_ar $name");
        return zypper_call("$cmd_ref --repo $name");
    }
}

=head2 fully_patch_system

 fully_patch_system();

Run C<zypper patch> twice. The first run will update the package manager,
the second run will update the system.

=cut
sub fully_patch_system {
    # first run, possible update of packager -- exit code 103
    zypper_call('patch --with-interactive -l', exitcode => [0, 102, 103], timeout => 3000);
    # workround for 11-SP4 s390 bsc#1155544
    if (is_sle('=11-SP4') && check_var('ARCH', 's390x') && check_var('BACKEND', 's390x')) {
        record_soft_failure 'bsc#1155544';
        handle_patch_11sp4_zvm();
    } else {
        # second run, full system update
        zypper_call('patch --with-interactive -l', exitcode => [0, 102], timeout => 6000);
    }
}

=head2 ssh_fully_patch_system

 ssh_fully_patch_system($host);

Connect to the remote host C<$host> using ssh and update the system by
running C<zypper patch> twice. The first run will update the package manager,
the second run will update the system.

=cut
sub ssh_fully_patch_system {
    my $host = shift;
    # first run, possible update of packager -- exit code 103
    my $ret = script_run("ssh root\@$host 'zypper -n patch --with-interactive -l'", 1500);
    die "Zypper failed with $ret" if ($ret != 0 && $ret != 102 && $ret != 103);
    # second run, full system update
    $ret = script_run("ssh root\@$host 'zypper -n patch --with-interactive -l'", 6000);
    die "Zypper failed with $ret" if ($ret != 0 && $ret != 102);
}

=head2 minimal_patch_system

 minimal_patch_system([version_variable => $version_variable]);

zypper doesn't offer --updatestack-only option before 12-SP1, use patch for sp0 to update packager
=cut
sub minimal_patch_system {
    my (%args) = @_;
    $args{version_variable} //= 'VERSION';
    if (is_sle('12-SP1+', get_var($args{version_variable}))) {
        zypper_call('patch --with-interactive -l --updatestack-only', exitcode => [0, 102, 103], timeout => 3000, log => 'minimal_patch.log');
    }
    else {
        zypper_call('patch --with-interactive -l', exitcode => [0, 102, 103], timeout => 3000, log => 'minimal_patch.log');
    }
}

=head2 zypper_search

 zypper_search($search_params);

Run zypper search with given command line arguments and parse the output into
an array of hashes.

=cut

sub zypper_search {
    my $params = shift;
    my @fields = ('status', 'name', 'type', 'version', 'arch', 'repository');
    my @ret;

    my $output = script_output("zypper -n se $params");

    for my $line (split /\n/, $output) {
        my @tokens = split /\s*\|\s*/, $line;
        next if $#tokens < $#fields;
        my %tmp;

        for (my $i = 0; $i < scalar @fields; $i++) {
            $tmp{$fields[$i]} = $tokens[$i];
        }

        push @ret, \%tmp;
    }

    # Remove header from package list
    shift @ret;
    return \@ret;
}

=head2 workaround_type_encrypted_passphrase

 workaround_type_encrypted_passphrase();

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
    return unless is_boot_encrypted();
    record_soft_failure 'workaround https://fate.suse.com/320901' if is_sle('12-SP4+');
    unlock_if_encrypted;
}

=head2 is_boot_encrypted

 is_boot_encrypted();

This will return C<1> if the env variables suggest
that the boot partition is encrypted.

=cut
sub is_boot_encrypted {
    return 0 if get_var('UNENCRYPTED_BOOT');
    return 0 if !get_var('ENCRYPT') && !get_var('FULL_LVM_ENCRYPT');
    # for Leap 42.3 and SLE 12 codestream the boot partition is not encrypted
    # Only aarch64 needs separate handling, it has unencrypted boot for fresh
    # installations, but has encrypted boot if cancel activation of existing
    # encrypted partitions
    # ppc64le on pre-storage-ng boot was part of encrypted LVM
    return 0 if !get_var('FULL_LVM_ENCRYPT') && !is_storage_ng && !is_ppc64le()
      && !(get_var('ENCRYPT_CANCEL_EXISTING') && get_var('ENCRYPT') && is_aarch64());
    # SLES 15: we don't have scenarios for cryptlvm which boot partion is unencrypted.
    return 0 if is_sle('15+') && !get_var('ENCRYPT');
    # If the encrypted disk is "just activated" it does not mean that the
    # installer would propose an encrypted installation again
    return 0 if get_var('ENCRYPT_ACTIVATE_EXISTING') && !get_var('ENCRYPT_FORCE_RECOMPUTE');

    return 1;
}

=head2 is_bridged_networking

 is_bridged_networking();

returns C<BRIDGED_NETWORKING>.

=cut
sub is_bridged_networking {
    return get_var('BRIDGED_NETWORKING');
}

=head2 set_bridged_networking

 set_bridged_networking();

Sets C<BRIDGED_NETWORKING> to C<1> if applicable.

=cut
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
hostname into DHCP/DNS.

If you change hostname using C<hostnamectl set-hostname>, then C<hostname -f>
will fail with I<hostname: Name or service not known> also DHCP/DNS don't know
about the changed hostname, you need to send a new DHCP request to update
dynamic DNS yast2-network module does
C<NetworkService.ReloadOrRestart if Stage.normal || !Linuxrc.usessh>
if hostname is changed via C<yast2 lan>.

=cut
sub set_hostname {
    my ($hostname) = @_;
    assert_script_run "hostnamectl set-hostname $hostname";
    assert_script_run "hostnamectl status|grep $hostname";
    assert_script_run "uname -n|grep $hostname";
    systemctl 'status network.service';
    save_screenshot;
    assert_script_run "if systemctl -q is-active network.service; then systemctl reload-or-restart network.service; fi";
}

=head2 assert_and_click_until_screen_change

 assert_and_click_until_screen_change($mustmatch [, $wait_change [, $repeat ]]);

This will repeat C<assert_and_click($mustmatch)> up to C<$repeat> times, trying
againg if the screen has not changed within C<$wait_change> seconds after
the C<assert_and_click>. Returns the number of attempts made.
C<$wait_change> defaults to 2 (seconds) and C<$repeat> defaults to 3.

=cut
sub assert_and_click_until_screen_change {
    my ($mustmatch, $wait_change, $repeat) = @_;
    $wait_change //= 2;
    $repeat      //= 3;
    my $i = 0;

    # This is not totally race free - wait_screen_change may timeout, then the screen
    # changes and the next assert_and_click will fail.
    for (; $i < $repeat; $i++) {
        my $changed = wait_screen_change(sub { assert_and_click $mustmatch }, $wait_change);
        last if $changed;
    }

    return $i;
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
        type_string "reboot\n";
        save_screenshot;
    }
}

=head2 assert_screen_with_soft_timeout

 assert_screen_with_soft_timeout($mustmatch, bugref => $bugref [,timeout => $timeout] [,soft_timeout => $soft_timeout] [,soft_failure_reason => $soft_failure_reason]);

Extending assert_screen with a soft timeout. When C<$soft_timeout> is hit, a
soft failure is recorded with the message C<$soft_failure_reason> but
C<assert_screen> continues until the (hard) timeout C<$timeout> is hit. This
makes sense when an assert screen should find a screen within a lower time but
still should not fail and continue until the hard timeout, e.g. to discover
performance issues.

There MUST be a C<$bugref> set for the softfail.
If it is not set this function will die.

Example:

 assert_screen_with_soft_timeout('registration-found', timeout => 300, soft_timeout => 60, bugref => 'bsc#123456');

=cut
sub assert_screen_with_soft_timeout {
    my ($mustmatch, %args) = @_;
    # as in assert_screen
    $args{timeout}      //= 30;
    $args{soft_timeout} //= 0;
    my $needle_info = ref($mustmatch) eq "ARRAY" ? join(',', @$mustmatch) : $mustmatch;
    die("\$args{bugref} is not set in assert_screen_with_soft_timeout") unless ($args{bugref});
    $args{soft_failure_reason} //= "$args{bugref}: needle(s) $needle_info not found within $args{soft_timeout}";
    if ($args{soft_timeout}) {
        die "soft timeout has to be smaller than timeout" unless ($args{soft_timeout} < $args{timeout});
        my $ret = check_screen $mustmatch, $args{soft_timeout};
        return $ret if $ret;
        record_soft_failure "$args{soft_failure_reason}";
    }
    return assert_screen $mustmatch, $args{timeout} - $args{soft_timeout};
}

=head2 pkcon_quit

 pkcon_quit();

Stop and mask packagekit service and wait until it is really dead.
This is needed to prevent access conflicts to the RPM database.

=cut
sub pkcon_quit {
    script_run("systemctl mask packagekit; systemctl stop packagekit; while pgrep packagekitd; do sleep 1; done");
}

=head2 addon_decline_license

 addon_decline_license();

TODO someone should document this
=cut
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

=head2 addon_license

 addon_license($addon);

TODO someone should document this
=cut
sub addon_license {
    my ($addon)  = @_;
    my $uc_addon = uc $addon;                      # variable name is upper case
    my @tags     = ('import-untrusted-gpg-key');
    push @tags, (get_var("BETA_$uc_addon") ? "addon-betawarning-$addon" : "addon-license-$addon");
  license: {
        do {
            # license on SLE15+ is shown only once during registration bsc#1057223
            # don't expect license if addon was already registered via SCC and license already viewed
            if (is_sle('15+') && check_var('SCC_REGISTER', 'installation') && get_var('SCC_ADDONS') =~ /$addon/ && !check_screen \@tags) {
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

=head2 addon_products_is_applicable

 addon_products_is_applicable();

Return C<1> if C<ADDONURL> is set and C<LIVECD> is unset.

=cut
sub addon_products_is_applicable {
    return !get_var('LIVECD') && get_var('ADDONURL');
}

=head2 noupdatestep_is_applicable

 noupdatestep_is_applicable();

Return C<1> if neither C<UPGRADE> nor C<LIVE_UPGRADE> is set.

=cut
sub noupdatestep_is_applicable {
    return !get_var("UPGRADE") && !get_var("LIVE_UPGRADE");
}

=head2 installwithaddonrepos_is_applicable

 installwithaddonrepos_is_applicable();

Return C<1> if installation should be done with addon repos
based on ENV variables.

=cut
sub installwithaddonrepos_is_applicable {
    return get_var("HAVE_ADDON_REPOS") && !get_var("UPGRADE") && !get_var("NET");
}

=head2 random_string

 random_string($length);

Returns a random string with length C<$length> (default: 4)
containing alphanumerical characters.

=cut
sub random_string {
    my ($self, $length) = @_;
    $length //= 4;
    my @chars = ('A' .. 'Z', 'a' .. 'z', 0 .. 9);
    return join '', map { @chars[rand @chars] } 1 .. $length;
}

=head2 handle_emergency

 handle_emergency();

Handle emergency shell or (systemd) emergency mode and dump
some basic logging information to the serial output.

=cut
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

 get_root_console_tty();

Returns tty number used designed to be used for root-console.
When console is not yet initialized, we cannot get it from arguments.
Since SLE 15 gdm is running on tty2, so we change behaviour for it and
openSUSE distris, except for Xen PV (bsc#1086243).

=cut
sub get_root_console_tty {
    return (!is_sle('<15') && !is_caasp && !check_var('VIRSH_VMM_TYPE', 'linux')) ? 6 : 2;
}

=head2 get_x11_console_tty

 get_x11_console_tty();

Returns tty number used designed to be used for X.
Since SLE 15 gdm is always running on tty7, currently the main GUI session
is running on tty2 by default, except for Xen PV and Hyper-V (bsc#1086243).
See also: bsc#1054782

=cut
sub get_x11_console_tty {
    my $new_gdm
      = !is_sle('<15')
      && !is_leap('<15.0')
      && !is_caasp
      && !check_var('VIRSH_VMM_FAMILY', 'hyperv')
      && !check_var('VIRSH_VMM_TYPE',   'linux')
      && !get_var('VERSION_LAYERED');
    # $newer_gdm means GDM version >= 3.32, which will start gnome desktop
    # on tty2 including auto-login cases. Also exclude cases which boot from
    # older versions in HDD
    my $newer_gdm
      = $new_gdm
      && !is_sle('<=15-SP2')
      && !is_leap('<15.2')
      && get_var('HDD_1', '') !~ /opensuse-42/;
    return (check_var('DESKTOP', 'gnome') && (get_var('NOAUTOLOGIN') || $newer_gdm) && $new_gdm) ? 2 : 7;
}

=head2 arrays_differ

 arrays_differ(\@array1, \@array2);

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

=head2 arrays_subset

 arrays_subset(\@array1, \@array2);

Compares two arrays passed by reference to identify if array1 is a subset of
array2.

Returns resulting array containing items of array1 that do not exist in array2.
If all the items of array1 exist in array2, returns an empty array (which means
array1 is a subset of array2).

=cut
sub arrays_subset {
    my ($array1_ref, $array2_ref) = @_;
    my @result;
    foreach my $item (@{$array1_ref}) {
        push(@result, $item) if !grep($item eq $_, @{$array2_ref});
    }
    return @result;
}

=head2 ensure_serialdev_permissions

 ensure_serialdev_permissions();

Grant user permission to access serial port immediately as well as persisting
over reboots. Used to ensure that testapi calls like script_run work for the
test user as well as root.

=cut
sub ensure_serialdev_permissions {
    my ($self) = @_;
    return if get_var('ROOTONLY');
    # ownership has effect immediately, group change is for effect after
    # reboot an alternative https://superuser.com/a/609141/327890 would need
    # handling of optional sudo password prompt within the exec
    # Need backwards support for SLES11-SP4 here, the command "gpasswd" and "stat" are only available with SLES-12 at least.
    if (is_sle && check_var('VERSION', '11-SP4')) {
        assert_script_run "chown $username /dev/$serialdev";
    }
    else {
        # when serial getty is started, it changes the group of serialdev from dialout to tty (but doesn't change it back when stopped)
        # let's make sure that both will work
        assert_script_run "chown $testapi::username /dev/$testapi::serialdev && usermod -a -G tty,dialout,\$(stat -c %G /dev/$testapi::serialdev) $testapi::username";
    }
}

=head2 disable_serial_getty

 disable_serial_getty();

Serial getty service pollutes serial output with login prompt, which
interferes with the output, e.g. when calling C<script_output>.
Login prompt messages on serial are used on some remote backend to
identify that system has been booted, so do not mask on non-qemu backends.
This is only necessary for Linux < 4.20.4 so skipped on more recent versions.

=cut
sub disable_serial_getty {
    my ($self) = @_;
    my $service_name = "serial-getty\@$testapi::serialdev";
    # Do not run on zVM as running agetty is required by iucvconn in order to work
    return if check_var('BACKEND', 's390x');
    # No need to apply on more recent kernels
    return unless is_sle('<=15-SP2') || is_leap('<=15.2');
    # Stop serial-getty on serial console to avoid serial output pollution with login prompt
    # Doing early due to bsc#1103199 and bsc#1112109
    # Mask if is qemu backend as use serial in remote installations e.g. during reboot
    my $mask = check_var('BACKEND', 'qemu');
    my $cmd  = $mask ? 'mask' : 'disable';
    disable_and_stop_service($service_name, mask_service => $mask, ignore_failure => 1);
    record_info 'serial-getty', "Serial getty $cmd for $testapi::serialdev";
}

=head2 exec_and_insert_password

 exec_and_insert_password($cmd);

1. Execute a command (C<$cmd>) that ask for a password

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
    if (get_var("VIRT_PRJ1_GUEST_INSTALL")) {
        type_password("novell");
    }
    else {
        type_password;
    }
    send_key "ret";

    if (is_serial_terminal()) {
        wait_serial(qr/$hashed_cmd-\d+-/);
    }
    else {
        wait_still_screen(stilltime => 10);
    }
}

=head2 shorten_url

 shorten_url($url, [wishid => $wishid]);

Shorten url via schort(s.qa.suse.de)
This is mainly used for autoyast url shorten to avoid limit of x3270 xedit.

C<$url> is the url to short. C<$wishid> is the prefered short url id.

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


=head2 _handle_login_not_found

 _handle_login_not_found($str);

Internal helper function used by C<reconnect_mgmt_console>.

=cut
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

=head2 reconnect_mgmt_console

 reconnect_mgmt_console([timeout => $timeout]);

After each reboot we have to reconnect to the management console on remote backends

=cut
sub reconnect_mgmt_console {
    my (%args) = @_;
    $args{timeout} //= 300;

    if (check_var('ARCH', 's390x')) {
        my $login_ready = qr/Welcome to /;
        $login_ready .= is_sle() ? qr/SUSE Linux Enterprise Server.*\(s390x\)/ : qr/openSUSE Tumbleweed/;
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

        if (!check_var('DESKTOP', 'textmode')) {
            if (check_var("UPGRADE", "1") && is_sle('15+') && is_sle('<15', get_var('HDDVERSION'))) {
                select_console 'root-console';
                if (script_run("iptables -S | grep 'A input_ext.*tcp.*dport 59.*-j ACCEPT'", 30) != 0) {
                    record_soft_failure('bsc#1154156 - After upgrade from 12SP5, SuSEfirewall2 blocks xvnc.socket on s390x');
                    script_run 'iptables -I input_ext -p tcp -m tcp --dport 5900:5999 -j ACCEPT';
                }
            }
            select_console('x11', await_console => 0);
        }
    }
    elsif (check_var('ARCH', 'ppc64le')) {
        if (check_var('BACKEND', 'spvm')) {
            select_console 'novalink-ssh', await_console => 0;
        } elsif (check_var('BACKEND', 'pvm_hmc')) {
            select_console 'powerhmc-ssh', await_console => 0;
        }
    }
    elsif (check_var('ARCH', 'x86_64')) {
        if (check_var('BACKEND', 'ipmi')) {
            select_console 'sol', await_console => 0;
            assert_screen [qw(qa-net-selection prague-pxe-menu)], 300;
            # boot to hard disk is default
            send_key 'ret';
        }
    }
    else {
        diag 'nothing special needed to reconnect management console';
    }
}

=head2 show_tasks_in_blocked_state

 show_tasks_in_blocked_state();

Dumps tasks that are in uninterruptable (blocked) state and wait for headline
of dump.

See L<https://github.com/torvalds/linux/blob/master/Documentation/admin-guide/sysrq.rst>.

=cut
sub show_tasks_in_blocked_state {
    # sending sysrqs doesn't work for svirt
    if (!check_var('BACKEND', 'svirt')) {
        send_key 'alt-sysrq-w';
        # info will be sent to serial tty
        wait_serial(qr/sysrq\s*:\s+show\s+blocked\s+state/i, 1);
        send_key 'ret';    # ensure clean shell prompt
    }
}

=head2 svirt_host_basedir

 svirt_host_basedir();

Return C<VIRSH_OPENQA_BASEDIR> or fall back to C</var/lib>.

=cut
sub svirt_host_basedir {
    return get_var('VIRSH_OPENQA_BASEDIR', '/var/lib');
}

=head2 prepare_ssh_localhost_key_login

 prepare_ssh_localhost_key_login($source_user);

Add the SSH key of C<$source_user> to the C<.ssh/authorized_keys> file of root.

=cut
sub prepare_ssh_localhost_key_login {
    my ($source_user) = @_;
    # in case localhost is already inside known_hosts
    if (script_run('test -e ~/.ssh/known_hosts') == 0) {
        assert_script_run('ssh-keygen -R localhost');
    }

    # generate ssh key
    if (script_run('! test -e ~/.ssh/id_rsa') == 0) {
        assert_script_run('ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa');
    }

    # add key to authorized_keys of root
    if ($source_user eq 'root') {
        assert_script_run('cat ~/.ssh/id_rsa.pub | tee -a ~/.ssh/authorized_keys');
    }
    else {
        assert_script_sudo('mkdir -p /root/.ssh');
        assert_script_sudo("cat /home/$source_user/.ssh/id_rsa.pub | tee -a /root/.ssh/authorized_keys");
    }
}

=head2 script_retry

 script_retry($cmd, [expect => $expect], [retry => $retry], [delay => $delay], [timeout => $timeout], [die => $die]);

Repeat command until expected result or timeout.

C<$expect> refers to the expected command exit code and defaults to C<0>.

C<$retry> refers to the number of retries and defaults to C<10>.

C<$delay> is the time between retries and defaults to C<30>.

The command must return within C<$timeout> seconds (default: 25).

If the command doesn't return C<$expect> after C<$retry> retries,
this function will die, if C<$die> is set.

Example:

 script_retry('ping -c1 -W1 machine', retry => 5);

=cut
sub script_retry {
    my ($cmd, %args) = @_;
    my $ecode   = $args{expect}  // 0;
    my $retry   = $args{retry}   // 10;
    my $delay   = $args{delay}   // 30;
    my $timeout = $args{timeout} // 30;
    my $die     = $args{die}     // 1;

    my $ret;
    for (1 .. $retry) {
        $ret = script_run "timeout " . ($timeout - 3) . " $cmd", $timeout;
        last if defined($ret) && $ret == $ecode;

        die("Waiting for Godot: $cmd") if $retry == $_ && $die == 1;
        sleep $delay;
    }

    return $ret;
}

=head2 script_run_interactive

 script_run_interactive($cmd, $prompt, $timeout);

For interactive command, input strings or keys according to the prompt message
in the run time. Pass arrayref C<$prompt> which contains the prompt message to
be matched (regex) and the answer with string or key to be typed. for example:

    [{
        prompt => qr/\(A\)llow/m,
        key    => 'a',
      },
      {
        prompt => qr/Enter Password or Pin/m,
        string => "testpasspw\n",
      },]

A "EOS~~~" message followed by return value will be printed as a mark
for the end of interaction after the command finished running.

If the first argument is C<undef>, only the sencond part will be processed - to
match output and react. If the second argument is undef, the first part will
be processed - to run the command without interaction with terminal output.
This is useful for some situation when you want to do more between inputing
command and the following interaction, eg. switch TTYs or detach the screen.
=cut
sub script_run_interactive {
    my ($cmd, $scan, $timeout) = @_;
    my $output;
    my $err_ret;
    my @words;
    my $endmark = 'EOS~~~';    # EOS == "End of Script"
    $timeout //= 180;

    if ($cmd) {
        script_run("(script -qe -a /dev/null -c \'", 0);
        script_run($cmd,                             0);
        # Can not get return value from script_run, so we have to do it in
        # the shell with $? following the endmark.
        script_run("\'; echo $endmark\$?) |& tee /dev/$serialdev", 0);
    }

    return if (!$scan);

    for my $k (@$scan) {
        push(@words, $k->{prompt});
    }

    push(@words, $endmark);

    {
        do {
            $output = wait_serial(\@words, $timeout) || die "No message matched!";

            last if ($output =~ /($endmark)0$/m);    # return value is 0
            die  if ($output =~ /$endmark/m);        # other return values

            for my $i (@$scan) {
                next if ($output !~ $i->{prompt});
                if ($i->{string}) {
                    type_string $i->{string};
                    last;
                }
                elsif ($i->{key}) {
                    send_key $i->{key};
                    last;
                }
                else {
                    die "$i->{prompt} - No flags specified";
                }
            }
        } while ($output);
    }
}

=head2 create_btrfs_subvolume

 create_btrfs_subvolume();

Create btrfs subvolume for C</boot/grub2/arm64-efi> before migration.
ref:bsc#1122591

=cut
sub create_btrfs_subvolume {
    my $fstype;
    $fstype = script_output("df -PT /boot/grub2/arm64-efi/ | grep -v \"Filesystem\" | awk '{print \$2}'");
    return if ('btrfs' ne chomp($fstype));
    my @sub_list = split(/\n/, script_output("btrfs subvolume list /boot/grub2/arm64-efi/", 120));
    foreach my $line (@sub_list) {
        return if ($line =~ /\/boot\/grub2\/arm64-efi/);
    }
    record_soft_failure 'bsc#1122591 - Create subvolume for aarch64 to make snapper rollback works';
    assert_script_run("mkdir -p /tmp/arm64-efi/");
    assert_script_run("cp -r /boot/grub2/arm64-efi/* /tmp/arm64-efi/");
    assert_script_run("rm -fr /boot/grub2/arm64-efi");
    assert_script_run("btrfs subvolume create /boot/grub2/arm64-efi");
    assert_script_run("cp -r /tmp/arm64-efi/* /boot/grub2/arm64-efi/");
    assert_script_run("rm -fr /tmp/arm64-efi/");
}


=head2 file_content_replace

 file_content_replace("filename",
       regex_to_find => text_to_replace,
       '--sed-modifier' => 'g',
       'another^&&*(textToFind' => "replacement")

Generify sed usage as config file modification tool.
allow to modify several items in one function call
by providing  C<regex_to_find> / C<text_to_replace> as hash key/value pairs

Special key C<--sed-modifier> allowing to add modifiers to expression.

Special key C<--debug> allow to output full file content into serial.
Disabled by default.

=cut
sub file_content_replace {
    my ($filename, %to_replace) = @_;
    $to_replace{'--sed-modifier'} //= '';
    $to_replace{'--debug'}        //= 0;
    my $sed_modifier = delete $to_replace{'--sed-modifier'};
    my $debug        = delete $to_replace{'--debug'};
    foreach my $key (keys %to_replace) {
        my $value = $to_replace{$key};
        $value =~ s/'/'"'"'/g;
        $value =~ s'/'\/'g;
        $key   =~ s/'/'"'"'/g;
        $key   =~ s'/'\/'g;
        assert_script_run(sprintf("sed -E 's/%s/%s/%s' -i %s", $key, $value, $sed_modifier, $filename));
    }
    script_run("cat $filename") if $debug;
}

sub handle_patch_11sp4_zvm {
    my $zypper_patch_conflict     = qr/^Choose from above solutions by number[\s\S,]* \[1/m;
    my $zypper_continue           = qr/^Continue\? \[y/m;
    my $zypper_patch_done         = qr/^ZYPPER-DONE/m;
    my $zypper_patch_notification = qr/^View the notifications now\? \[y/m;
    my $zypper_error              = qr/^Abort, retry, ignore\? \[a/m;
    my $timeout                   = 6000;
    my $patch_checks              = [
        $zypper_patch_conflict, $zypper_continue, $zypper_patch_done, $zypper_patch_notification, $zypper_error
    ];
    script_run("(zypper patch --with-interactive -l;echo ZYPPER-DONE) | tee /dev/$serialdev", 0);
    my $out = wait_serial($patch_checks, $timeout);
    while ($out) {
        if ($out =~ $zypper_patch_conflict) {
            save_screenshot;
            send_key "3";
            send_key "ret";
        }
        elsif ($out =~ $zypper_continue) {
            save_screenshot;
            send_key "y";
            send_key "ret";
        }
        elsif ($out =~ $zypper_patch_notification) {
            save_screenshot;
            send_key "n";
            send_key "ret";
        }
        elsif ($out =~ $zypper_patch_done) {
            save_screenshot;
            last;
        }
        elsif ($out =~ $zypper_error) {
            die "zypper patch error";
            save_screenshot;
        }
        $out = wait_serial($patch_checks, $timeout);
    }
}

=head2 assert_file_content
    assert_file_content( "path", value );

It could check a file be point to 'path' whether include 'value'.

=cut

sub assert_file_content {
    my ($param, $value) = @_;
    assert_script_run("cat $param | grep $value");
}
1;
