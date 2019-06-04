# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: General library for every system that uses transactional-updates
# Like CaasP, MicroOS and transactional-server
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>

package transactional;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use caasp 'microos_reboot';
use power_action_utils 'power_action';
use version_utils qw(is_opensuse is_caasp);

our @EXPORT = qw(
  process_reboot
  check_reboot_changes
  rpmver
  trup_call
  trup_install
  trup_shell
);

sub process_reboot {
    my $trigger = shift // 0;

    if (is_caasp) {
        microos_reboot $trigger;
    } else {
        power_action('reboot', observe => !$trigger, keepconsole => 1);

        # Replace by wait_boot if possible
        assert_screen 'grub2', 100;
        send_key 'ret';
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
    my $time    = time;
    my $mounted = "mnt-$time";
    my $default = "def-$time";
    assert_script_run "mount | grep 'on / ' | egrep -o 'subvolid=[0-9]*' | cut -d'=' -f2 > $mounted";
    assert_script_run "btrfs su get-default / | cut -d' ' -f2 > $default";
    my $change_happened = script_run "diff $mounted $default";

    # If changes are expected check that default subvolume changed
    die "Error during diff" if $change_happened > 1;
    die "Change expected: $change_expected, happeed: $change_happened" if $change_expected != $change_happened;

    # Reboot into new snapshot
    process_reboot 1 if $change_happened;
}

# Return names and version of packages for transactional-update tests
sub rpmver {
    my $q    = shift;
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

    my $vr = "$rpm{$iobs}{v}-$rpm{$iobs}{r}";
    # Returns expected package version after installation
    return $vr if $q eq 'vr';
    # Returns rpm path for initial installation
    return " update-test-trivial/update-test-$q-$vr.$arch.rpm";
}

# Optionally skip exit status check in case immediate reboot is expected
sub trup_call {
    my $cmd   = shift;
    my $check = shift // 1;
    $cmd .= " > /dev/$serialdev";
    $cmd .= " ; echo trup-\$?- > /dev/$serialdev" if $check;

    script_run "transactional-update --no-selfupdate $cmd", 0;
    if ($cmd =~ /pkg |ptf /) {
        if (wait_serial "Continue?") {
            send_key "ret";
            # Abort update of broken package
            if ($cmd =~ /\bup(date)?\b/ && $check == 2) {
                die 'Abort dialog not shown' unless wait_serial('Abort');
                send_key 'ret';
            }
        }
        else {
            die "Confirmation dialog not shown";
        }
    }
    # Check if trup passed
    wait_serial 'trup-0-' if $check == 1;
    # Broken package update fails
    wait_serial 'trup-1-' if $check == 2;
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
        process_reboot(1);
    }

    # By the end, all pkgs should be installed
    assert_script_run("rpm -q $input");
}

# Run command in transactional shell and reboot to apply changes
# Optional parameter reboot can disable rebooting into new snapshot
sub trup_shell {
    my ($cmd, %args) = @_;
    $args{reboot} //= 1;

    type_string("transactional-update shell; echo trup_shell-status-\$? > /dev/$serialdev\n");
    wait_still_screen;
    type_string("$cmd\n");
    type_string("exit\n");
    wait_serial('trup_shell-status-0') || die "'transactional-update shell' didn't finish";

    process_reboot 1 if $args{reboot};
}

