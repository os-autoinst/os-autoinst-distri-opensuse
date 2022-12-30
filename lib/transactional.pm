# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: General library for every system that uses transactional-updates
# Like MicroOS and transactional-server
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>

package transactional;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use utils;
use Carp;
use microos 'microos_reboot';
use power_action_utils qw(power_action prepare_system_shutdown);
use version_utils;
use utils 'reconnect_mgmt_console';
use Utils::Backends;
use Utils::Architectures;

our @EXPORT = qw(
  process_reboot
  check_reboot_changes
  rpmver
  trup_call
  trup_install
  trup_shell
  get_utt_packages
  enter_trup_shell
  exit_trup_shell_and_reboot
  reboot_on_changes
  record_kernel_audit_messages
);

# Download files needed for transactional update tests
sub get_utt_packages {
    # SLE and SUSE MicroOS need an additional repo for testing
    if (is_sle || is_sle_micro) {
        assert_script_run 'curl -O ' . data_url("microos/utt.repo");
    } elsif (is_leap_micro || is_alp) {
        assert_script_run 'curl -o utt.repo ' . data_url("microos/utt-leap.repo");
    }

    # Different testfiles for SUSE MicroOS and openSUSE MicroOS
    my $tarball = 'utt-';
    $tarball .= is_opensuse() ? 'opensuse' : 'sle';
    $tarball .= '-' . get_required_var('ARCH') . '.tgz';

    assert_script_run 'curl -O ' . data_url("microos/$tarball");
    assert_script_run "tar xzvf $tarball";
}

# After automated rollback initialization passes by GRUB twice.
# Here it is handled the first time GRUB is displayed
sub handle_first_grub {
    enter_cmd "reboot";
    if (is_s390x || is_pvm) {
        reconnect_mgmt_console(timeout => 500, grub_expected_twice => 1);
    }
    else {
        assert_screen 'grub2', 100;
        wait_screen_change { send_key 'ret' };
    }
}

sub process_reboot {
    my (%args) = @_;
    $args{trigger} //= 0;
    $args{automated_rollback} //= 0;
    $args{expected_grub} //= 1;

    # Switch to root-console as we need VNC to check for grub and for login prompt
    my $prev_console = current_console();
    select_console 'root-console', await_console => 0;

    handle_first_grub if ($args{automated_rollback});

    if (is_microos || is_sle_micro && !is_s390x) {
        microos_reboot $args{trigger};
        record_kernel_audit_messages();
    } elsif (is_backend_s390x) {
        prepare_system_shutdown;
        enter_cmd "reboot";
        opensusebasetest::wait_boot(opensusebasetest->new(), bootloader_time => 200);
        record_kernel_audit_messages();
    } else {
        power_action('reboot', observe => !$args{trigger}, keepconsole => 1);
        if (is_s390x || is_pvm) {
            reconnect_mgmt_console(timeout => 500) unless $args{automated_rollback};
        }
        if (!is_s390x && $args{expected_grub}) {
            if (is_aarch64 && check_screen('tianocore-mainmenu', 30)) {
                # Use firmware boot manager of aarch64 to boot HDD, when needed
                opensusebasetest::handle_uefi_boot_disk_workaround();
            }
            # Replace by wait_boot if possible
            assert_screen 'grub2', 150;
            wait_screen_change { send_key 'ret' };
        }
        assert_screen 'linux-login', 200;

        # Login & clear login needle
        select_console 'root-console';
        record_kernel_audit_messages();
        assert_script_run 'clear';
    }

    # Switch to the previous console
    select_console $prev_console;
}

# Reboot if there's a diff between the current FS and the new snapshot
sub check_reboot_changes {
    my $change_expected = shift // 1;

    # Compare currently mounted and default subvolume
    my $time = time;
    my $mounted = "mnt-$time";
    my $default = "def-$time";
    assert_script_run "mount | grep 'on / ' | grep -E -o 'subvolid=[0-9]*' | cut -d'=' -f2 > $mounted";
    assert_script_run "btrfs su get-default / | cut -d' ' -f2 > $default";
    my $change_happened = script_run "diff $mounted $default";

    # If changes are expected check that default subvolume changed
    die "Error during diff" if $change_happened > 1;
    die "Change expected: $change_expected, happened: $change_happened" if $change_expected != $change_happened;

    # Reboot into new snapshot
    process_reboot(trigger => 1) if $change_happened;
}



=head2 record_kernel_audit_messages

Record the SELinux messages before the auditd daemon has been started, if present. If there are no such entries, this function has no effect.

=cut

sub record_kernel_audit_messages {
    my %args = testapi::compat_args({log_upload => 0}, ['log_upload'], @_);
    my $output = script_output("journalctl -k | grep 'audit:.*avc:' || true");
    return unless ($output);    # Don't log anything if there is no output
    record_info("AVC-k", "Kernel audit messages:\n\n$output", result => 'softfail');

    # Upload the same log and don't fail on errors (supplemental material)
    if ($args{log_upload}) {
        script_run("journalctl -k | grep 'audit:.*avc:' > /var/tmp/k-audit.log");
        upload_logs("/var/tmp/k-audit.log", fail_ok => 1);
        script_run("rm -f /var/tmp/k-audit.log");
    }
}

# Return names and version of packages for transactional-update tests
sub rpmver {
    my $q = shift;
    my $arch = get_var('ARCH');
    my $iobs = is_opensuse() ? 'obs' : 'ibs';

    # rpm version & release numbers
    my %rpm = (
        obs => {v => '5', r => '2.1'},
        ibs => {v => '5', r => '2.29'},
    );

    if ($arch eq 'aarch64') {
        $rpm{obs} = {v => '5', r => '4.3'};
    }

    if ($arch eq 'ppc64le') {
        $rpm{obs} = {v => '5.1', r => '1.1'};
    }

    my $vr = "$rpm{$iobs}{v}-$rpm{$iobs}{r}";
    # Returns expected package version after installation
    return $vr if $q eq 'vr';
    # Returns rpm path for initial installation
    return " update-test-trivial/update-test-$q-$vr.$arch.rpm";
}

# Optionally skip exit status check in case immediate reboot is expected
sub trup_call {
    my ($cmd, %args) = @_;
    $args{timeout} //= 180;
    $args{exit_code} //= 0;

    # Always wait for rollback.service to be finished before triggering manually transactional-update
    ensure_rollback_service_not_running();

    my $script = "transactional-update $cmd > /dev/$serialdev";
    # Only print trup-0- if it's reliably read later (see below)
    $script .= "; echo trup-\$?- | tee -a /dev/$serialdev" unless $cmd =~ /reboot / && $args{exit_code} == 0;
    script_run $script, 0;
    if ($cmd =~ /pkg |ptf /) {
        if ($cmd =~ /(^|\s)-\w*n\w*( --\w*)* (pkg|ptf)/) {
            record_info 'non-interactive', 'The transactional-update command is in non-interactive mode';
        } elsif (wait_serial "Continue?") {
            send_key "ret";
            # Abort update of broken package
            if ($cmd =~ /\bup(date)?\b/ && $args{exit_code} == 1) {
                die 'Abort dialog not shown' unless wait_serial('Abort');
                send_key 'ret';
            }
        } else {
            die "Confirmation dialog not shown";
        }
    }

    # If we expect a reboot on success, the trup-0- might not reach the console.
    # Check for t-u's own output just before the reboot instead.
    if ($cmd =~ /reboot / && $args{exit_code} == 0) {
        wait_serial(qr/New default snapshot is/, timeout => $args{timeout}) || die "transactional-update didn't finish";
        return;
    }

    my $res = wait_serial(qr/trup-\d+-/, timeout => $args{timeout}) || die "transactional-update didn't finish";
    my $ret = ($res =~ /trup-(\d+)-/)[0];
    die "transactional-update returned with $ret, expected $args{exit_code}" unless $ret == $args{exit_code};
}

# Install a pkg in MicroOS
sub trup_install {
    my $input = shift;

    # rebootmgr has to be turned off as prerequisity for this to work
    script_run "rebootmgrctl set-strategy off";

    my @pkg = split(' ', $input);
    my $necessary;
    foreach (@pkg) {
        $necessary .= "$_ " if script_run("rpm -q $_");
    }
    if ($necessary) {
        trup_call("pkg install $necessary");
        process_reboot(trigger => 1);
    }

    # By the end, all pkgs should be installed
    assert_script_run("rpm -q $input");
}

# Run command in transactional shell and reboot to apply changes
# Optional parameter reboot can disable rebooting into new snapshot
sub trup_shell {
    my ($cmd, %args) = @_;
    $args{reboot} //= 1;

    enter_cmd("transactional-update shell; echo trup_shell-status-\$? > /dev/$serialdev");
    wait_still_screen;
    enter_cmd("$cmd");
    enter_cmd("exit");
    wait_serial('trup_shell-status-0') || die "'transactional-update shell' didn't finish";

    process_reboot(trigger => 1) if $args{reboot};
}

# When transactional-update is triggered manually is required to wait for rollback.service
# to not be running. This is needed because rollback.service is triggered on first boot
# after updates or rollbacks.
# The transactional-update.timer waits for that service to be finished before starting itself.
# In general automated services will make sure that they don't block each other,
# but this does not apply when manual triggering of the script.
sub ensure_rollback_service_not_running {
    for (1 .. 24) {
        my $output = script_output("systemctl show -p SubState --value rollback.service");
        $output =~ '^(start|running)$' ? sleep 10 : last;
    }
}

=head2 enter_trup_shell

  enter_trup_shell(global_options => $global_options, shell_options => $shell_options)

Enter into transactional update shell by entering command on transactional server:
transactional-update $global_options shell $shell_options. The two arguments for
this subroutine, global_options and shell_options, are all text strings that are
composed of space separated options for transactional-update and shell respectively.

=cut

sub enter_trup_shell {
    my (%args) = @_;

    $args{global_options} //= '';
    $args{shell_options} //= '';
    enter_cmd("transactional-update $args{global_options} shell $args{shell_options}; echo trup_shell-status-\$? > /dev/$serialdev");
    wait_still_screen;
    assert_script_run("uname -a");
}

=head2 exit_trup_shell_and_reboot

  exit_trup_shell_and_reboot()

Quit transactional update shell by entering exit. Check if any changes that request
reboot to take effect. This subroutine should be used together with enter_trup_shell.

=cut

sub exit_trup_shell_and_reboot {
    enter_cmd("exit");
    wait_serial('trup_shell-status-0') || croak("transactional-update shell did not finish");
    wait_still_screen;
    reboot_on_changes();
}

=head2 reboot_on_changes

  reboot_on_changes

Check whether new snapshot is generated and reboot into this new snapshot if there
are changes happened.

=cut

sub reboot_on_changes {
    # Compare currently mounted and default subvolume
    my $mountedsubvol = script_output("mount | grep 'on / ' | grep -E -o 'subvolid=[0-9]*' | cut -d'=' -f2", proceed_on_failure => 0);
    my $defaultsubvol = script_output("btrfs su get-default / | cut -d' ' -f2", proceed_on_failure => 0);
    my $has_change = abs(int($defaultsubvol) - int($mountedsubvol));

    if ($has_change) {
        # Reboot into new snapshot
        process_reboot(trigger => 1);
    }
    else {
        record_info("No reboot needed", "Reboot saved because there are no changes happened and no new snapshot generated");
    }
}

1;
