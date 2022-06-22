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

    handle_first_grub if ($args{automated_rollback});

    if (is_microos || is_sle_micro && !is_s390x) {
        microos_reboot $args{trigger};
    } elsif (is_backend_s390x) {
        prepare_system_shutdown;
        enter_cmd "reboot";
        opensusebasetest::wait_boot(opensusebasetest->new(), bootloader_time => 200);
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
        assert_script_run 'clear';
    }
}

# Reboot if there's a diff between the current FS and the new snapshot
sub check_reboot_changes {
    my $change_expected = shift // 1;

    # Compare currently mounted and default subvolume
    my $time = time;
    my $mounted = "mnt-$time";
    my $default = "def-$time";
    assert_script_run "mount | grep 'on / ' | egrep -o 'subvolid=[0-9]*' | cut -d'=' -f2 > $mounted";
    assert_script_run "btrfs su get-default / | cut -d' ' -f2 > $default";
    my $change_happened = script_run "diff $mounted $default";

    # If changes are expected check that default subvolume changed
    die "Error during diff" if $change_happened > 1;
    die "Change expected: $change_expected, happened: $change_happened" if $change_expected != $change_happened;

    # Reboot into new snapshot
    process_reboot(trigger => 1) if $change_happened;
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
    $script .= "; echo trup-\$?- > /dev/$serialdev" unless $cmd =~ /reboot / && $args{exit_code} == 0;
    script_run $script, 0;
    if ($cmd =~ /pkg |ptf /) {
        if (wait_serial "Continue?") {
            send_key "ret";
            # Abort update of broken package
            if ($cmd =~ /\bup(date)?\b/ && $args{exit_code} == 1) {
                die 'Abort dialog not shown' unless wait_serial('Abort');
                send_key 'ret';
            }
        }
        else {
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
