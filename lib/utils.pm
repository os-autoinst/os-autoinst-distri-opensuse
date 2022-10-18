# Copyright 2015-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi qw(is_serial_terminal :DEFAULT);
use lockapi 'mutex_wait';
use mm_network;
use version_utils qw(is_sle_micro is_microos is_leap is_public_cloud is_sle is_sle12_hdd_in_upgrade is_storage_ng is_jeos package_version_cmp);
use Utils::Architectures;
use Utils::Systemd qw(systemctl disable_and_stop_service);
use Utils::Backends;
use Mojo::UserAgent;
use zypper qw(wait_quit_zypper);
use Storable qw(dclone);

our @EXPORT = qw(
  generate_results
  pars_results
  check_console_font
  clear_console
  type_string_slow
  type_string_very_slow
  type_string_slow_extended
  enter_cmd_slow
  enter_cmd_very_slow
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
  set_zypper_lock_timeout
  workaround_type_encrypted_passphrase
  is_boot_encrypted
  is_bridged_networking
  set_bridged_networking
  assert_screen_with_soft_timeout
  quit_packagekit
  wait_for_purge_kernels
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
  get_root_console_tty
  get_x11_console_tty
  OPENQA_FTP_URL
  IN_ZYPPER_CALL
  arrays_differ
  arrays_subset
  ensure_serialdev_permissions
  assert_and_click_until_screen_change
  exec_and_insert_password
  shorten_url
  reconnect_mgmt_console
  set_hostname
  show_tasks_in_blocked_state
  show_oom_info
  svirt_host_basedir
  disable_serial_getty
  script_retry
  script_run_interactive
  create_btrfs_subvolume
  create_raid_loop_device
  file_content_replace
  ensure_ca_certificates_suse_installed
  is_efi_boot
  install_patterns
  common_service_action
  script_output_retry
  validate_script_output_retry
  get_secureboot_status
  assert_secureboot_status
  susefirewall2_to_firewalld
  permit_root_ssh
  permit_root_ssh_in_sol
  cleanup_disk_space
  package_upgrade_check
  test_case
  @all_tests_results
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

# set flag IN_ZYPPER_CALL in zypper_call and unset when leaving
our $IN_ZYPPER_CALL = 0;

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
    enter_cmd "pty=`virsh dumpxml $name 2>/dev/null | grep \"console type=\" | sed \"s/'/ /g\" | awk '{ print \$5 }'`";
    enter_cmd "echo \$pty";
}

=head2 type_line_svirt

 type_line_svirt($string [, expect => $expect] [, timeout => $timeout] [, fail_message => $fail_message]);

Sends C<$string> to the svirt terminal, waits up to C<$timeout> seconds
and expects C<$expect> to be returned on the terminal if C<$expect> is set.
If the expected text is not found, it will fail with C<$fail_message>.

=cut

sub type_line_svirt {
    my ($string, %args) = @_;
    enter_cmd "echo $string > \$pty";
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
        wait_screen_change { send_key 'alt-t'; send_key 'alt-y' };    # import/yes, depending on variant
    }
    else {
        record_info('Cancel import', 'Untrusted gpg key is NOT imported');
        wait_screen_change { send_key 'alt-c'; send_key 'spc' };    # cancel/no, depending on variant
    }
}

=head2 integration_services_check_ip

 integration_services_check_ip();

Check that guest IP address that host and guest see is the same.
Die, if this is not the case.

=cut

sub integration_services_check_ip {
    # Host-side of Integration Services
    my $vmname = console('svirt')->name;
    my $ips_host_pov;
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        (undef, $ips_host_pov) = console('svirt')->run_cmd(
            'powershell -Command "Get-VM ' . $vmname . ' | Get-VMNetworkAdapter | Format-Table -HideTableHeaders IPAddresses"', wantarray => 1);
    }
    elsif (check_var('VIRSH_VMM_FAMILY', 'vmware')) {
        (undef, $ips_host_pov) = console('svirt')->run_cmd(
            "set -x; vmid=\$(vim-cmd vmsvc/getallvms | awk '/$vmname/ { print \$1 }');" .
              "if [ \$vmid ]; then vim-cmd vmsvc/get.guest \$vmid | awk '/ipAddress/ {print \$3}' " .
              "| head -n1 | sed -e 's/\"//g' | sed -e 's/,//g'; fi", domain => 'sshVMwareServer', wantarray => 1);
    }
    $ips_host_pov =~ m/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/;
    $ips_host_pov = $1;
    # Guest-side of Integration Services
    my $ips_guest_pov = script_output("default_iface=\$(awk '\$2 == 00000000 { print \$1 }' /proc/net/route); ip addr show dev \"\$default_iface\" | awk '\$1 == \"inet\" { sub(\"/.*\", \"\", \$2); print \$2 }'");
    record_info('IP (host)', $ips_host_pov);
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
    integration_services_check_ip();
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
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
    elsif (is_backend_s390x) {
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
        if ($args{check_typed_password}) {
            unless (check_screen "encrypted_disk-typed_password", 30) {
                record_info("Invalid password", "Not all password characters were typed successfully, retyping");
                send_key "backspace" for (0 .. 9);
                type_password;
                assert_screen "encrypted_disk-typed_password";
            }
        }
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
    enter_cmd "clear";
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
    # for the needle to match, for migration, need wait root console
    my $flavor = get_var('FLAVOR');
    select_console('root-console', await_console => ($flavor =~ /Migration/) ? 1 : 0);

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

    type_string $string, max_interval => SLOW_TYPING_SPEED;
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

    type_string $string, max_interval => VERY_SLOW_TYPING_SPEED;

    if (get_var('WINTER_IS_THERE')) {
        sleep 3;
    }
    else {
        wait_still_screen(1, 3);
    }
}

=head2 enter_cmd_slow

 enter_cmd_slow($cmd);

Enter a command with C<SLOW_TYPING_SPEED> to avoid losing keys.

=cut

sub enter_cmd_slow {
    my ($cmd) = @_;

    enter_cmd $cmd, max_interval => SLOW_TYPING_SPEED;
}

=head2 enter_cmd_very_slow

 enter_cmd_very_slow($cmd);

Enter a command even slower with C<VERY_SLOW_TYPING_SPEED>. Compare to
C<type_string_very_slow>.

=cut

sub enter_cmd_very_slow {
    my ($cmd) = @_;

    enter_cmd $cmd, max_interval => VERY_SLOW_TYPING_SPEED;
    wait_still_screen(1, 3);
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
    my $command = shift;
    my %args = @_;
    my $allow_exit_codes = $args{exitcode} || [0];
    my $timeout = $args{timeout} || 700;
    my $log = $args{log};
    my $dumb_term = $args{dumb_term} // is_serial_terminal;

    my $printer = $log ? "| tee /tmp/$log" : $dumb_term ? '| cat' : '';
    die 'Exit code is from PIPESTATUS[0], not grep' if $command =~ /^((?!`).)*\| ?grep/;

    $IN_ZYPPER_CALL = 1;
    # Retrying workarounds
    my $ret;
    my $search_conflicts = 'awk \'BEGIN {print "Processing conflicts - ",NR; group=0}
                    /Solverrun finished with an ERROR/,/statistics/{ print group"|",
                    $0; if ($0 ~ /statistics/ ){ print "EOL"; group++ }; }\'\
                    /var/log/zypper.log
                    ';
    for (1 .. 5) {
        $ret = script_run("zypper -n $command $printer; ( exit \${PIPESTATUS[0]} )", $timeout);
        die "zypper did not finish in $timeout seconds" unless defined($ret);
        if ($ret == 4) {
            if (script_run('grep "Error code.*502" /var/log/zypper.log') == 0) {
                die 'According to bsc#1070851 zypper should automatically retry internally. Bugfix missing for current product?';
            }
            elsif (get_var('WORKAROUND_PREINSTALL_CONFLICT')) {
                record_soft_failure('poo#113033 Workaround maintenance package preinstall conflict, job cloned with WORKAROUND_PREINSTALL_CONFLICT');
                script_run q(zypper -n rm $(awk '/conflicts with/ {print$7}' /var/log/zypper.log|uniq));
                next;
            }
            elsif (script_run('grep "Solverrun finished with an ERROR" /var/log/zypper.log') == 0) {
                my $conflicts = script_output($search_conflicts);
                record_info("Conflict", $conflicts, result => 'fail');
                diag "Package conflicts found, not retrying anymore" if $conflicts;
                last;
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

    # log all install and remove actions for later use by tests/console/zypper_log_packages.pm
    my @packages = split(" ", $command);
    my $dry_run = 0;
    for (my $i = 0; $i < scalar(@packages); $i++) {
        if ($packages[$i] eq "--root" || $packages[$i] eq "-R") {
            splice(@packages, $i, 2);
        }
        elsif ($packages[$i] eq "--name" || $packages[$i] eq "-n") {
            splice(@packages, $i, 2);
        }
        elsif ($packages[$i] eq "--from") {
            splice(@packages, $i, 2);
        }
        elsif ($packages[$i] eq "--repo" || $packages[$i] eq "-r") {
            splice(@packages, $i, 2);
        }
        elsif ($packages[$i] eq "--download") {
            splice(@packages, $i, 2);
        }
        elsif ($packages[$i] eq "--dry-run" || $packages[$i] eq "--download-only" || $packages[$i] eq '-d') {
            $dry_run = 1;
        }
        elsif ($packages[$i] eq "--solver-focus") {
            splice(@packages, $i, 2);
        }
    }
    @packages = grep(/^[^-]/, @packages);
    my $zypper_action = shift(@packages);
    $zypper_action = "install" if ($zypper_action eq "in");
    $zypper_action = "remove" if ($zypper_action eq "rm");
    if ($zypper_action =~ m/^(install|remove)$/ && !$dry_run) {
        push(@{$testapi::distri->{zypper_packages}}, {
                raw_command => $command,
                action => $zypper_action,
                packages => \@packages,
                return_code => $ret,
                test => {
                    module => $autotest::current_test->{name},
                    category => $autotest::current_test->{category}
                }
        });
    }

    upload_logs("/tmp/$log") if $log;

    unless (grep { $_ == $ret } @$allow_exit_codes) {
        upload_logs('/var/log/zypper.log');
        my $msg = "'zypper -n $command' failed with code $ret";
        if ($ret == 104) {
            $msg .= " (ZYPPER_EXIT_INF_CAP_NOT_FOUND)\n\nRelated zypper logs:\n";
            script_run('tac /var/log/zypper.log | grep -F -m1 -B100000 "Hi, me zypper" | tac | grep \'\(SolverRequester.cc\|THROW\|CAUGHT\)\' > /tmp/z104.txt');
            $msg .= script_output('cat /tmp/z104.txt');
        }
        elsif ($ret == 107) {
            $msg .= " (ZYPPER_EXIT_INF_RPM_SCRIPT_FAILED)\n\nRelated zypper logs:\n";
            script_run('tac /var/log/zypper.log | grep -F -m1 -B100000 "Hi, me zypper" | tac | grep \'RpmPostTransCollector.cc(executeScripts):.* scriptlet failed, exit status\' > /tmp/z107.txt');
            $msg .= script_output('cat /tmp/z107.txt') . "\n\n";
        }
        else {
            script_run('tac /var/log/zypper.log | grep -F -m1 -B100000 "Hi, me zypper" | tac | grep \'Exception.cc\' > /tmp/zlog.txt');
            $msg .= "\n\nRelated zypper logs:\n";
            $msg .= script_output('cat /tmp/zlog.txt');
        }
        die $msg;
    }
    $IN_ZYPPER_CALL = 0;
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
    my $name = $args{name} // '';
    my $priority = $args{priority} // undef;
    my $params = $args{params} // '';
    my $no_gpg_check = $args{no_gpg_check} // '';

    $no_gpg_check = $no_gpg_check ? "--no-gpgcheck" : "";
    my $prioarg = defined($priority) && !is_sle('<=12') ? "-p $priority" : "";
    my $cmd_ar = "--gpg-auto-import-keys ar -f $prioarg $no_gpg_check $params $url";
    my $cmd_mr = "mr $prioarg $url";
    my $cmd_ref = "--gpg-auto-import-keys ref";

    # repo file
    if (!$name) {
        zypper_call($cmd_ar);
        zypper_call($cmd_mr) if defined($priority) && is_sle('<12');
        return zypper_call($cmd_ref);
    }

    # URI alias
    my $out = script_output("LC_ALL=C zypper lr $name 2>&1", proceed_on_failure => 1);
    if ($out =~ /Repository.*$name.*not found/i) {
        zypper_call("$cmd_ar $name");
        zypper_call($cmd_mr) if $priority && is_sle('<12');
        return zypper_call("$cmd_ref --repo $name");
    }
}

=head2 fully_patch_system

 fully_patch_system();

Run C<zypper patch> twice. The first run will update the package manager,
the second run will update the system.

=cut

sub fully_patch_system {
    # special handle for 11-SP4 s390 install
    if (is_sle('=11-SP4') && is_s390x && is_backend_s390x) {
        # first run, possible update of packager -- exit code 103
        zypper_call('patch --with-interactive -l', exitcode => [0, 102, 103], timeout => 3000);
        handle_patch_11sp4_zvm();
        return;
    }

    # Repeatedly call zypper patch until it returns something other than 103 (package manager updates)
    my $ret = 1;
    # Add -q to reduce the unnecessary log output.
    # Reduce the pressure of serial port when running hyperv test with sle15.
    # poo#115454
    my $zypp_opt = check_var('VIRSH_VMM_FAMILY', 'hyperv') ? '-q' : '';
    for (1 .. 3) {
        $ret = zypper_call("$zypp_opt patch --with-interactive -l", exitcode => [0, 4, 102, 103], timeout => 6000);
        last if $ret != 103;
    }

    if (($ret == 4) && is_sle('>=12') && is_sle('<15')) {
        record_soft_failure 'bsc#1176655 openQA test fails in patch_sle - binutils-devel-2.31-9.29.1.aarch64 requires binutils = 2.31-9.29.1';
        my $para = '';
        $para = '--force-resolution' if get_var('FORCE_DEPS');
        $ret = zypper_call("patch --with-interactive -l $para", exitcode => [0, 102], timeout => 6000);
        save_screenshot;
    }

    die "Zypper failed with $ret" if ($ret != 0 && $ret != 102);
}

=head2 ssh_fully_patch_system

 ssh_fully_patch_system($host);

Connect to the remote host C<$host> using ssh and update the system by
running C<zypper patch> twice. The first run will update the package manager,
the second run will update the system.

=cut

sub ssh_fully_patch_system {
    my $remote = shift;

    my $cmd_time = time();
    # first run, possible update of packager -- exit code 103
    my $ret = script_run("ssh $remote 'sudo zypper -n patch --with-interactive -l'", 1500);
    record_info('zypper patch', 'The command zypper patch took ' . (time() - $cmd_time) . ' seconds.');
    die "Zypper failed with $ret" if ($ret != 0 && $ret != 102 && $ret != 103);

    $cmd_time = time();
    # second run, full system update
    $ret = script_run("ssh $remote 'sudo zypper -n patch --with-interactive -l'", 6000);
    record_info('zypper patch', 'The second command zypper patch took ' . (time() - $cmd_time) . ' seconds.');
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

=head2 set_zypper_lock_timeout

 set_zypper_lock_timeout($timeout);

Set how many seconds zypper will wait for other processes to release
the system lock. If this function is called without arguments, it'll set
timeout to 300 seconds.

=cut

sub set_zypper_lock_timeout {
    my $timeout = shift // 300;

    script_run("export ZYPP_LOCK_TIMEOUT='$timeout'");
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
    record_info(
        "LUKS pass", "Workaround for 'Provide kernel interface to pass LUKS password from bootloader'.\n" .
          'For further info, please, see https://fate.suse.com/320901, https://jira.suse.com/browse/SLE-2941, ' .
          'https://jira.suse.com/browse/SLE-3976') if is_sle('12-SP4+');
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
    if (is_svirt and !is_s390x) {
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
On MM test with supportserver restart network to get IP and hostname from DHCP
and test the connection with hostname
C<NetworkService.ReloadOrRestart if Stage.normal || !Linuxrc.usessh>
if hostname is changed via C<yast2 lan>.

=cut

sub set_hostname {
    my ($hostname) = @_;
    assert_script_run "hostnamectl set-hostname $hostname";
    assert_script_run "hostnamectl status|grep $hostname";
    assert_script_run "uname -n|grep $hostname";
    if (get_var('USE_SUPPORT_SERVER')) {
        # get hostname of two nodes
        my ($node1, $node2);
        my $count = 30;
        if (get_var('HA_CLUSTER_JOIN')) {    # on node02
            $node2 = get_var('HOSTNAME');
            $node1 = $node2;
            $node2 =~ s/02/01/;
        }
        else {
            $node1 = get_var('HOSTNAME');    # on node01 or client node03
            $node2 = $node1;
            $node1 =~ s/0[13]/02/;
        }

        # restart network and test connection to itself and other node
        do {
            die 'At least one of two nodes is not reachable' if $count-- == 0;
            systemctl 'restart network.service';
            sleep 2;
        } while script_run("nc -zvw10 $node1 22 && nc -zvw10 $node2 22", die_on_timeout => 0);
    }
    else {
        systemctl 'status network.service';
    }
    save_screenshot;
    assert_script_run "if systemctl -q is-active network.service; then systemctl reload-or-restart network.service; fi";
}

=head2 assert_and_click_until_screen_change

 assert_and_click_until_screen_change($mustmatch [, $wait_change [, $repeat ]]);

This will repeat C<assert_and_click($mustmatch)> up to C<$repeat> times, trying
againg if the screen has not changed within C<$wait_change> seconds after
the C<assert_and_click>. Returns the number of attempts made.
C<$wait_change> defaults to 2 (seconds) and C<$repeat> defaults to 3.

You can check if the screen changed by using an explicit repeat and comparing it
to the returned number of attempts. If the value equals repeat the screen didn't change.

=cut

sub assert_and_click_until_screen_change {
    my ($mustmatch, $wait_change, $repeat) = @_;
    $wait_change //= 2;
    $repeat //= 3;
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
        enter_cmd "reboot";
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
    $args{timeout} //= 30;
    $args{soft_timeout} //= 0;
    my $needle_info = ref($mustmatch) eq "ARRAY" ? join(',', @$mustmatch) : $mustmatch;
    die("\$args{bugref} is not set in assert_screen_with_soft_timeout") unless ($args{bugref});
    $args{soft_failure_reason} //= "$args{bugref}: needle(s) $needle_info not found within $args{soft_timeout}";
    if ($args{soft_timeout}) {
        die "soft timeout has to be smaller than timeout" unless ($args{soft_timeout} < $args{timeout});
        my $ret = check_screen $mustmatch, $args{soft_timeout};
        return $ret if $ret;
        record_info('Softfail', "$args{soft_failure_reason}", result => 'softfail');
    }
    return assert_screen $mustmatch, $args{timeout} - $args{soft_timeout};
}

=head2 quit_packagekit

 quit_packagekit();

Stop and mask packagekit service and wait until it is really dead.
This is needed to prevent access conflicts to the RPM database.

=cut

sub quit_packagekit {
    script_run("systemctl mask packagekit; systemctl stop packagekit; while pgrep packagekitd; do sleep 1; done");
}

=head2 wait_for_purge_kernels

 wait_for_purge_kernels();

Wait until purge-kernels is done
Prevent RPM lock e.g. SUSEConnect fail

=cut

sub wait_for_purge_kernels {
    script_run('while pgrep purge-kernels; do sleep 1; done');
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
    my ($addon) = @_;
    my $uc_addon = uc $addon;    # variable name is upper case
    my @tags = ('import-untrusted-gpg-key');
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
        type_password;
        send_key 'ret';
        script_run "cat /run/initramfs/rdsosreport.txt > /dev/$serialdev";
        script_run "echo \"\n--------------Beginning of journalctl--------------\n\" > /dev/$serialdev";
        script_run "journalctl --no-pager -o short-precise > /dev/$serialdev";
        die "hit emergency shell";
    }
    elsif (match_has_tag('emergency-mode')) {
        type_password;
        send_key 'ret';
        script_run "journalctl --no-pager -o short-precise > /dev/$serialdev";
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
    my @types = $args->{type} ? @{$args->{type}} : 'service';
    my @actions = $args->{action} ? @{$args->{action}} : 'stop';
    foreach my $action (@actions) {
        foreach my $type (@types) {
            systemctl "$action $name.$type";
        }
    }
}

=head2 get_root_console_tty

 get_root_console_tty();

Returns tty number used designed to be used for root-console.
When console is not yet initialized, we cannot get it from arguments.
Since SLE 15 gdm is running on tty2, so we change behaviour for it and
openSUSE distris, except for Xen PV (bsc#1086243).

=cut

sub get_root_console_tty {
    return (!is_sle('<15') && !is_microos && !check_var('VIRSH_VMM_TYPE', 'linux')) ? 6 : 2;
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
      && !is_microos
      && !check_var('VIRSH_VMM_FAMILY', 'hyperv')
      && !check_var('VIRSH_VMM_TYPE', 'linux')
      && !get_var('VERSION_LAYERED');
    # $newer_gdm means GDM version >= 3.32, which will start gnome desktop
    # on tty2 including auto-login cases.
    my $newer_gdm
      = $new_gdm
      && !is_sle('<15-SP2')
      && !is_leap('<15.2');
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
        assert_script_run("chown $testapi::username /dev/$testapi::serialdev && usermod -a -G tty,dialout,\$(stat -c %G /dev/$testapi::serialdev) $testapi::username", timeout => 120);
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
    return if is_backend_s390x;
    # No need to apply on more recent kernels
    return unless is_sle('<=15-SP2') || is_leap('<=15.2');
    # Stop serial-getty on serial console to avoid serial output pollution with login prompt
    # Doing early due to bsc#1103199 and bsc#1112109
    # Mask if is qemu backend as use serial in remote installations e.g. during reboot
    my $mask = is_qemu;
    my $cmd = $mask ? 'mask' : 'disable';
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
        enter_cmd " ; echo $hashed_cmd-\$?-";
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

    my $res = $ua->post('s.qa.suse.de' => form => {url => $url, wishId => $args{wishid}})->result;
    if ($res->is_success) { return $res->body }
    elsif ($res->is_error) { die "Shorten url got $res->code response: $res->message" }
    else { die "Shorten url failed with unknown error" }
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
    if (is_backend_s390x) {
        diag 'Trying to look for "blocked tasks" with magic sysrq';
        console('x3270')->sequence_3270("String(\"^-w\\n\")");
        my $r = console('x3270')->expect_3270(buffer_full => qr/(MORE\.\.\.|HOLDING)/);
        save_screenshot;
        $error_details = join("\n", @$r);
    }

    die "unknown error, system couldn't boot. Detailed bootup log:\n$error_details";
}

=head2 _handle_firewall

 _handle_firewall();

Internal helper function used by C<reconnect_mgmt_console>.

=cut

sub _handle_firewall {
    select_console 'root-console';
    return if script_run("iptables -S | grep 'A input_ext.*tcp.*dport 59.*-j ACCEPT'", 30) == 0;
    wait_quit_zypper;
    my $ret;
    my $max_num = 3;
    # Sometimes wait_quit_zypper still not wait enough timeout
    for (1 .. $max_num) {
        $ret = zypper_call("in susefirewall2-to-firewalld", exitcode => [0, 7]);
        if ($ret == 7) {
            record_info('The ZYPP library is still locked, wait more seconds');
            wait_quit_zypper;
        } else {
            last;
        }
    }

    susefirewall2_to_firewalld();
}

=head2 reconnect_mgmt_console

 reconnect_mgmt_console([timeout => $timeout]);

After each reboot we have to reconnect to the management console on remote backends.
C<$timeout> can be set to some specific time and if during reboot GRUB is shown twice C<grub_expected_twice>
can be set to 1.

=cut

sub reconnect_mgmt_console {
    my (%args) = @_;
    $args{timeout} //= 300;
    $args{grub_expected_twice} //= 0;

    if (is_s390x) {
        my $login_ready = serial_terminal::get_login_message();
        console('installation')->disable_vnc_stalls;

        # different behaviour for z/VM and z/KVM
        if (is_backend_s390x) {
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
                select_console('svirt');
                save_svirt_pty;
                if ($args{grub_expected_twice}) {
                    wait_serial('Press enter to boot the selected OS') ||
                      diag 'Could not find boot selection, continuing nevertheless, trying to boot';
                    type_line_svirt '';
                }
                wait_serial('GNU GRUB', $args{grub_timeout}) ||
                  diag 'Could not find GRUB screen, continuing nevertheless, trying to boot';
                type_line_svirt '', expect => $login_ready, timeout => $args{timeout}, fail_message => 'Could not find login prompt';
            }
        }

        if (!check_var('DESKTOP', 'textmode')) {
            if (check_var("UPGRADE", "1") && is_sle('15+') && is_sle('<15', get_var('HDDVERSION'))) {
                _handle_firewall;
            }
            reset_consoles;
            select_console('x11', await_console => 0);
        }
    }
    elsif (is_ppc64le) {
        if (is_spvm) {
            select_console 'novalink-ssh', await_console => 0;
        } elsif (is_pvm_hmc) {
            select_console 'powerhmc-ssh', await_console => 0;
            if ($args{grub_expected_twice}) {
                check_screen 'grub2', 60;
                wait_screen_change { send_key 'ret' };
            }
        }
    }
    elsif (is_x86_64) {
        if (is_ipmi) {
            select_console 'sol', await_console => 0;
            assert_screen([qw(qa-net-selection prague-pxe-menu grub2)], 300);
            # boot to hard disk is default
            send_key 'ret';
        }
    }
    elsif (is_aarch64) {
        if (is_ipmi) {
            select_console 'sol', await_console => 0;
            # aarch64 baremetal machine takes longer to boot than 5 minutes
            assert_screen([qw(qa-net-selection prague-pxe-menu grub2)], 600);
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
    if (has_ttys) {
        send_key 'alt-sysrq-t';
        send_key 'alt-sysrq-w';
        # info will be sent to serial tty
        wait_serial(qr/sysrq\s*:\s+show\s+blocked\s+state/i);

        # If the 'An error occured during the installation.' OK popup has popped up,
        # do not press the 'return' key, because it will result in all ttys logging out.
        send_key 'ret' unless (check_screen 'linuxrc-install-fail');

    }
}

=head2 show_oom_info

 show_oom_info

Show logs about an out of memory process kill.

=cut

sub show_oom_info {
    if (script_run('dmesg | grep "Out of memory"') == 0) {
        my $oom = script_output('dmesg | grep "Out of memory"', proceed_on_failure => 1);
        if (has_ttys) {
            send_key 'alt-sysrq-m';
            $oom .= "\n\n" . script_output('journalctl -kb | tac | grep -F -m1 -B1000 "sysrq: Show Memory" | tac', proceed_on_failure => 1);
            $oom .= "\n\n% free -h\n" . script_output('free -h', proceed_on_failure => 1);
        }
        record_info('OOM KILL', $oom, result => 'fail');
    }
}

=head2 svirt_host_basedir

 svirt_host_basedir();

Return C<VIRSH_OPENQA_BASEDIR> or fall back to C</var/lib>.

=cut

sub svirt_host_basedir {
    return get_var('VIRSH_OPENQA_BASEDIR', '/var/lib');
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
    my $ecode = $args{expect} // 0;
    my $retry = $args{retry} // 10;
    my $delay = $args{delay} // 30;
    my $timeout = $args{timeout} // 30;
    my $die = $args{die} // 1;

    my $ret;

    my $exec = "timeout $timeout $cmd";
    # Exclamation mark needs to be moved before the timeout command, if present
    if (substr($cmd, 0, 1) eq "!") {
        $cmd = substr($cmd, 1);
        $cmd =~ s/^\s+//;    # left trim spaces after the exclamation mark
        $exec = "! timeout $timeout $cmd";
    }
    for (1 .. $retry) {
        # timeout for script_run must be larger than for the 'timeout ...' command
        $ret = script_run($exec, ($timeout + 3));
        last if defined($ret) && $ret == $ecode;

        die("Waiting for Godot: $cmd") if $retry == $_ && $die == 1;
        sleep $delay if ($delay > 0);
    }

    return $ret;
}

=head2 script_output_retry

 script_output_retry($cmd, [retry => $retry], [delay => $delay], [timeout => $timeout], [die => $die]);

Repeat command until expected result or timeout. Return the output of the command on success.

C<$expect> refers to the expected command exit code and defaults to C<0>.

C<$retry> refers to the number of retries and defaults to C<10>.

C<$delay> is the time between retries and defaults to C<30>.

The command must return within C<$timeout> seconds (default: 25).

If the command doesn't return C<$expect> after C<$retry> retries,
this function will die, if C<$die> is set.

Example:

 script_output_retry('ping -c1 -W1 machine', retry => 5);

=cut

sub script_output_retry {
    my ($cmd, %args) = @_;
    my $retry = $args{retry} // 10;
    my $delay = $args{delay} // 30;
    my $timeout = $args{timeout} // 30;
    my $die = $args{die} // 1;

    my $exec = "timeout --foreground " . ($timeout - 3) . " $cmd";
    for (1 .. $retry) {
        my $ret = eval { script_output($exec, timeout => $timeout, proceed_on_failure => 0); };
        return $ret if ($ret);
        sleep $delay;
        record_info('Retry', 'script_output failed, retrying.');
    }
    die("Waiting for Godot: $cmd") if $die;
}


=head2 validate_script_output_retry

 validate_script_output_retry($cmd, $check, [retry => $retry], [delay => $delay], [timeout => $timeout]);

Repeat command until validate_script_output succeeds or die. Return the output of the command on success.

C<$retry> refers to the number of retries and defaults to C<10>.

C<$delay> is the time between retries and defaults to C<30>.

If the command doesn't succeed after C<$retry> retries,
this function will die.

Example:

 validate_script_output_retry('ping -c1 -W1 machine', m/1 packets transmitted/, retry => 5, delay => 60);

=cut

sub validate_script_output_retry {
    my ($cmd, $check, %args) = @_;
    $args{retry} //= 10;
    $args{delay} //= 30;
    $args{timeout} //= 90;
    $args{proceed_on_failure} //= 1;
    my $retry = delete $args{retry};
    my $delay = delete $args{delay};
    my $timeout = delete $args{timeout};
    my $ret;
    my $exec = "timeout --foreground --kill-after 5s ${timeout}s";
    # Exclamation mark needs to be moved before the timeout command, if present
    if (substr($cmd, 0, 1) eq "!") {
        $cmd = substr($cmd, 1);
        $cmd =~ s/^\s+//;    # left trim spaces after the exclamation mark
        $exec = "! $exec";
    }
    $exec = "$exec $cmd";
    $timeout += 8;    # timeout for script_run must be larger than for the 'timeout ...' command

    for (1 .. $retry) {
        eval { $ret = validate_script_output($exec, $check, $timeout, %args); };
        return $ret if (defined($ret));
        record_info("Retry", "validate_script_output failed or timed out. Retrying...");
        sleep $delay;
    }
    die("Can't validate output after $retry retries");
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
        script_run($cmd, 0);
        # Can not get return value from script_run, so we have to do it in
        # the shell with $? following the endmark.
        script_run("\'; echo $endmark\$?) |& tee /dev/$serialdev", 0);
    }

    return if (!$scan);

    for my $k (@$scan) {
        push(@words, $k->{prompt});
    }

    # Hack: '$' doesn't match '\r\n' line endings, so use '\s' instead
    push(@words, qr/${endmark}\d+\s/m);

    {
        do {
            $output = wait_serial(\@words, $timeout) || die "No message matched!";

            last if ($output =~ /${endmark}0\s/m);    # return value is 0
            die if ($output =~ /${endmark}/m);    # other return values

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
    $fstype = script_output("df -PT /boot/grub2/arm64-efi/ | grep -v \"Filesystem\" | awk '{print \$2}'", 120);
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

=head2 create_raid_loop_device

 create_raid_loop_device([raid_type => $raid_type], [device_num => $device_num], [file_size => $file_size]);

Create a raid array over loop devices.
Raid type is C<$raid_type>, using C<$device_num> number of loop device,
with the size of each device being C<$file_size> megabytes.

Example to create a RAID C<5> array over C<3> loop devices, C<200> Mb each:
    create_raid_loop_device(raid_type => 5, device_num => 3, file_size => 200)

=cut

sub create_raid_loop_device {
    my %args = @_;
    my $raid_type = $args{raid_type} // 1;
    my $device_num = $args{device_num} // 2;
    my $file_size = $args{file_size} // 100;
    my $loop_devices = "";

    for my $num (1 .. $device_num) {
        my $raid_file = "raid_file" . $num;
        assert_script_run("fallocate -l ${file_size}M $raid_file");

        my $loop_device = script_output("losetup -f");
        assert_script_run("losetup $loop_device $raid_file");

        $loop_devices .= $loop_device . " ";
    }

    assert_script_run("yes|mdadm --create /dev/md/raid_over_loop --level=$raid_type --raid-devices=$device_num $loop_devices");
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
    $to_replace{'--debug'} //= 0;
    my $sed_modifier = delete $to_replace{'--sed-modifier'};
    my $debug = delete $to_replace{'--debug'};
    foreach my $key (keys %to_replace) {
        my $value = $to_replace{$key};
        $value =~ s/'/'"'"'/g;
        $value =~ s'/'\/'g;
        $key =~ s/'/'"'"'/g;
        $key =~ s'/'\/'g;
        assert_script_run(sprintf("sed -E 's/%s/%s/%s' -i %s", $key, $value, $sed_modifier, $filename));
    }
    script_run("cat $filename") if $debug;
}

sub handle_patch_11sp4_zvm {
    my $zypper_patch_conflict = qr/^Choose from above solutions by number[\s\S,]* \[1/m;
    my $zypper_continue = qr/^Continue\? \[y/m;
    my $zypper_patch_done = qr/^ZYPPER-DONE/m;
    my $zypper_patch_notification = qr/^View the notifications now\? \[y/m;
    my $zypper_error = qr/^Abort, retry, ignore\? \[a/m;
    my $timeout = 6000;
    my $patch_checks = [
        $zypper_patch_conflict, $zypper_continue, $zypper_patch_done, $zypper_patch_notification, $zypper_error
    ];
    script_run("(zypper patch --with-interactive -l;echo ZYPPER-DONE) | tee /dev/$serialdev", 0);
    my $out = wait_serial($patch_checks, $timeout);
    while ($out) {
        if ($out =~ $zypper_patch_conflict) {
            save_screenshot;
            if (check_var("BREAK_DEPS", '1')) {
                send_key "3";
                send_key "ret";
            }
            elsif (check_var("WORKAROUND_DEPS", '1')) {
                send_key "2";
                send_key "ret";
            }
            else {
                die 'Dependency problems';
            }
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

=head2 ensure_ca_certificates_suse_installed
    ensure_ca_certificates_suse_installed();

This functions checks if ca-certificates-suse is installed and if it is not it adds the repository and installs it.

=cut

sub ensure_ca_certificates_suse_installed {
    return unless is_sle || is_sle_micro;
    if (script_run('rpm -qi ca-certificates-suse') == 1) {
        my $host_version = get_var("HOST_VERSION") ? 'HOST_VERSION' : 'VERSION';
        my $distversion = get_required_var($host_version) =~ s/-SP/_SP/r;    # 15 -> 15, 15-SP1 -> 15_SP1
        zypper_call("ar --refresh http://download.suse.de/ibs/SUSE:/CA/SLE_$distversion/SUSE:CA.repo");
        if (is_sle_micro) {
            transactional::trup_call('--continue pkg install ca-certificates-suse');
        } else {
            zypper_call("in ca-certificates-suse");
        }
    }
}

# non empty */sys/firmware/efi/* must exist in UEFI mode
sub is_efi_boot {
    return !!script_output('test -d /sys/firmware/efi/ && ls -A /sys/firmware/efi/', proceed_on_failure => 1);
}

#   Function: parse the output from script_output to get the pattern list
#   Reason  : sometimes script_output with 'zypper pt -u' will cost a lot of time to return,
#   which cause the console have some system message in the output. we need filt out these
#   info before we process the result.
#   parameters:
#   $cmd   : the command line
#   $start : the line that start with $start, which is we want
#   return :  an array of pattern list
sub get_pattern_list {
    my ($cmd, $start) = @_;

    my $pkg_name;
    my @column = ();
    my @pkg_list = ();
    my %seen = ();
    my @unique = ();

    my @pkg_lines = split(/\n/, script_output($cmd, 120));

    foreach my $line (@pkg_lines) {
        $line =~ s/^\s+|\s+$//g;
        # In a regular expression, all chars between the \Q and \E are escaped.
        next if ($line !~ m/^\Q$start\E/);
        # filter out the spaces in each filed
        @column = map { s/^\s*|\s*$//gr } split(/\|/, $line);
        # pkg_name is the 2nd field seperated by '|'
        $pkg_name = $column[1];
        push @pkg_list, $pkg_name;
    }

    if (@pkg_list) {
        # unique and sort the @pkg_list
        %seen = map { $_ => 1 } @pkg_list;
        @unique = sort keys %seen;
    }

    return @unique;
}

=head2 install_patterns
    install_patterns();

This functions install extra patterns if var PATTERNS is set.

=cut

sub install_patterns {
    my $pcm = 0;
    my @pt_list;
    my @pt_list_un;
    my @pt_list_in;
    my $pcm_list = 0;
    my $cf_selected = 0;

    if (is_sle('15+')) {
        $pcm_list = 'Amazon_Web_Services|Google_Cloud_Platform|Microsoft_Azure';
    }
    else {
        $pcm_list = 'Amazon-Web-Services|Google-Cloud-Platform|Microsoft-Azure';
    }
    @pt_list_in = get_pattern_list "zypper pt -i", "i";
    # install all patterns from product.
    if (check_var('PATTERNS', 'all')) {
        @pt_list_un = get_pattern_list "zypper pt -u", "|";
    }
    # install certain pattern from parameter.
    else {
        @pt_list_un = split(/,/, get_var('PATTERNS'));
    }

    my %installed_pt = ();
    foreach (@pt_list_in) {
        # Remove pattern common-criteria if already installed, poo#73645
        if ($_ =~ /common-criteria/) {
            zypper_call("remove -t pattern $_");
            next;
        }
        $installed_pt{$_} = 1;
    }
    @pt_list = sort grep(!$installed_pt{$_}, @pt_list_un);
    $pcm = grep /$pcm_list/, @pt_list_in;

    for my $pt (@pt_list) {
        # if pattern is set default, skip
        next if ($pt =~ /default/);
        # For Public cloud module test we need skip Instance pattern if outside of public cloud images.
        next if (($pt =~ /Instance/) && !is_public_cloud);
        # Cloud patterns are conflict by each other, only install cloud pattern from single vender.
        if ($pt =~ /$pcm_list/) {
            next unless $pcm == 0;
            # For Public cloud module test we need install 'Tools' but not 'Instance' pattern if outside of public cloud images.
            next if (($pt !~ /Tools/) && !is_public_cloud);
            $pt .= '*' if (is_public_cloud);
            $pcm = 1;
        }
        # Only one CFEngine pattern can be installed
        if ($pt =~ /CFEngine|CFEngien/) {
            if ($cf_selected == 0) {
                $cf_selected = 1;
            }
            elsif ($cf_selected == 1) {
                record_soft_failure 'bsc#950763 CFEngine pattern is listed twice in installer';
                next;
            }
        }
        # skip the installation of "SAP Application Server Base", poo#75058.
        if (($pt =~ /sap_server/) && is_sle('=11-SP4')) {
            next;
        }
        # For Public cloud module test we need install 'Tools' but not 'Instance' pattern if outside of public cloud images.
        next if (($pt =~ /OpenStack/) && ($pt !~ /Tools/) && !is_public_cloud);
        # if pattern is common-criteria and PATTERNS is all, skip, poo#73645
        next if (($pt =~ /common-criteria/) && check_var('PATTERNS', 'all'));
        zypper_call("in -t pattern $pt", timeout => 1800);
    }
}

sub common_service_action {
    my ($service, $type, $action) = @_;

    if ($type eq 'SystemV') {
        if ($action eq 'enable') {
            assert_script_run 'chkconfig ' . $service . ' on';
        } elsif ($action eq 'is-enabled') {
            assert_script_run 'chkconfig ' . $service . ' | grep on';
        } elsif ($action eq 'is-active') {
            assert_script_run '/etc/init.d/' . $service . ' status | grep running';
        } else {
            assert_script_run '/etc/init.d/' . $service . ' ' . $action;
        }
    } elsif ($type eq 'Systemd') {
        systemctl $action . ' ' . $service;
    } else {
        die "Unsupported service type, please check it again.";
    }
}

sub get_secureboot_status {
    my $sbvar = '8be4df61-93ca-11d2-aa0d-00e098032b8c-SecureBoot';
    my $ret;

    if (is_sle('<12-SP3')) {
        $ret = script_output("efivar -pn $sbvar");

        if ($ret =~ m/^Value:\s*^\d+\s+(\d+)/ms) {
            $ret = $1;
        }
    } else {
        $ret = script_output("efivar -dn $sbvar");
    }

    die "Efivar returned invalid SecureBoot state $ret" if $ret !~ m/^[0-9]+/i;
    return $ret != 0;
}

sub assert_secureboot_status {
    my $expected = shift;

    my $state = get_secureboot_status;
    my $statestr = $state ? 'on' : 'off';
    die "Error: SecureBoot is $statestr" if $state xor $expected;
}

sub susefirewall2_to_firewalld {
    my $timeout = 360;
    $timeout = 1200 if is_aarch64;
    assert_script_run('susefirewall2-to-firewalld -c', timeout => $timeout);
    assert_script_run('firewall-cmd --permanent --zone=external --add-service=vnc-server', timeout => 60);
    # On some platforms such as Aarch64, the 'firewalld restart'
    # can't finish in the default timeout.

    systemctl 'restart firewalld', timeout => $timeout;
    script_run('iptables -S', timeout => $timeout);
    set_var('SUSEFIREWALL2_SERVICE_CHECK', 1);
}

=head2 permit_root_ssh
    permit_root_ssh();

Due to bsc#1173067, openssh now no longer allows RootLogin
using password auth on Tumbleweed, the latest SLE16 and
Leap16 will sync with Tumbleweed as well.

=cut

sub permit_root_ssh {
    if (is_sle('<16') || is_leap('<16.0')) {
        my $results = script_run("grep 'PermitRootLogin yes' /etc/ssh/sshd_config");
        if (!$results) {
            assert_script_run("sed -i 's/^PermitRootLogin.*\$/PermitRootLogin yes/' /etc/ssh/sshd_config");
            assert_script_run("systemctl restart sshd");
        }
    }
    else {
        assert_script_run("echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf");
        assert_script_run("systemctl restart sshd");
    }
}

=head2 permit_root_ssh_in_sol
    permit_root_ssh_in_sol();

for ipmi backend, PermitRootLogin has to be set in sol console
however, assert_script_run and script_run is not stable in sole console
enter_cmd or type_string are acceptable

=cut

sub permit_root_ssh_in_sol {
    my $sshd_config_file = shift;

    $sshd_config_file //= "/etc/ssh/sshd_config";
    enter_cmd("[ `grep \"^PermitRootLogin *yes\" $sshd_config_file | wc -l` -gt 0 ] || (echo 'PermitRootLogin yes' >>$sshd_config_file; systemctl restart sshd)");
}

=head2 cleanup_disk_space
    cleanup_disk_space();

In fully_patch_system and minimal_patch_system, we'll create so many
snapshots. which will cost large part of the disk space. We need to
delete these snapshots before the migration only if the available space
is less than DISK_LOW_WATERMARK.

=cut

sub cleanup_disk_space {
    # we just do the disk clean up only if the available disk space is
    # less than DISK_LOW_WATERMARK
    return unless get_var("DISK_LOW_WATERMARK");
    my $avail = script_output('findmnt -n -D -r -o avail / | awk \'{print $1+0}\'', timeout => 120);
    diag "available space = $avail GB";
    return if ($avail > get_var("DISK_LOW_WATERMARK"));

    record_soft_failure "bsc#1192331", "Low diskspace on Filesystem root";

    my $ret = script_run("snapper --help | grep disable-used-space");
    my $disable = $ret ? '' : '--disable-used-space';
    my @snap_lists = split /\n/, script_output("snapper list $disable | grep important= | grep -v single | awk \'{print \$1}\'");
    foreach my $snapid (@snap_lists) {
        assert_script_run("snapper delete -s $snapid", timeout => 120) if ($snapid > 3);
    }

    # set the snapshot number to 5-10
    assert_script_run('snapper -croot set-config NUMBER_LIMIT=5-10');
}


=head2 package_upgrade_check
    package_upgrade_check();

This function is used for checking if the package
is upgraded to the required version

Sample config of parameter of the function below:
my $pkg_list = {ibmtss => '1.6.0'};
here, 'libmtss' is the package name, and '1.6.0'
is target version which needs to be upgrated to

=cut

sub package_upgrade_check {
    my ($pkg_list, $fail_flag) = @_;
    foreach my $pkg_name (keys %$pkg_list) {
        my $current_ver = script_output("rpm -q --qf '%{version}\n' $pkg_name");
        record_info("Package $pkg_name version", "Current version is $current_ver, target version is $pkg_list->{$pkg_name}");
        next if (package_version_cmp($current_ver, $pkg_list->{$pkg_name}) >= 0);
        if ($fail_flag) {
            die "Error: package $pkg_name is not upgraded yet, please check with developer";
        }
        else {
            record_info('Softfail', "Warning: package $pkg_name is not upgraded yet", result => 'softfail');
        }
    }
}

=head2 _validate_result
    _validate_result();

This is a private method which is used by C<generate_results> to convert the
results in a string representation. At the moment the status that are supported
are {PASS,FAIL}.

The method takes as the only argument the return of a perl statement or
subroutine.

=cut

sub _validate_result {
    my $result = shift;
    if ($result == 0) {
        return 'PASS';
    } elsif ($result == 1) {
        return 'FAIL';
    } else {
        return undef;
    }
}

=head2 generate_results
    generate_results();

This function is used to construct a hash suitable for representation in junit
xml format.

=cut

sub generate_results {
    my ($name, $description, $result) = @_;

    my %results = (
        test => $name,
        description => $description,
        result => _validate_result($result)
    );
    return %results;
}

=head2 pars_results
    pars_results();

Takes C<test> as an argument. C<test> is an array of hashes which contain the
test results. They usually are generated by C<generate_results>. Those are
parsed and create the junit xml representation.

=cut

sub pars_results {
    my ($testsuite, $xmlfile, @test) = @_;

    # check if there are some single test failing
    # and if so, make sure the whole testsuite will fail
    my $fail_check = 0;
    for my $i (@test) {
        if ($i->{result} eq 'FAIL') {
            $fail_check++;
        }
    }

    if ($fail_check > 0) {
        script_run(qq{echo "<testsuite name='$testsuite' errors='1'>" >> $xmlfile});
    } else {
        script_run(qq{echo "<testsuite name='$testsuite'>" >> $xmlfile});
    }

    # parse all results and provide expected xml file
    for my $i (@test) {
        if ($i->{result} eq 'FAIL') {
            script_run("echo \"<testcase name='$i->{test}' errors='1'>\" >>  $xmlfile");
        } else {
            script_run("echo \"<testcase name='$i->{test}'>\" >> $xmlfile");
        }
        script_run("echo \"<system-out>\" >> $xmlfile");
        script_run("echo $i->{description} >>  $xmlfile");
        script_run("echo \"</system-out>\" >> $xmlfile");
        script_run("echo \"</testcase>\" >> $xmlfile");
    }
    script_run("echo \"</testsuite>\" >> $xmlfile");
}

our @all_tests_results;

=head2 test_case
    test_case($name, $description, $result);

C<test_case> can produce a data_structure which C<pars_results> can utilize.
Using C<test_case> in an OpenQA module you are able to /name/ and describe
the whole test as subtasks, in a XUnit format.

=cut

sub test_case {
    my ($name, $description, $result) = @_;
    my %results = generate_results($name, $description, $result);
    push(@all_tests_results, dclone(\%results));
}

1;
