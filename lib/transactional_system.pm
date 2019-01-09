# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: General library for every system that uses transactional-updates
# Like CaasP, Kubic and transactional-server
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>

package transactional_system;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use caasp 'process_reboot';

our @EXPORT = qw(
  check_reboot_changes
  rpmver
  trup_call
  trup_install
);

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
    my $d    = get_var 'DISTRI';
    my $arch = get_var('ARCH');

    # package name | initial version
    my %rpm = (
        kubic => {
            fn => '5-2.1',
            in => '2.1',
        },
        caasp => {
            fn => '5-5.3.61',
            in => '5.3.61',
        });

    if ("$arch" eq "aarch64") {
        %rpm = (
            kubic => {
                fn => '5-4.3',
                in => '4.3',
            });
    }

    # Returns expected package version after installation / update
    if ($q eq 'in') {
        return $rpm{$d}{$q};
    }
    # Returns rpm path for initial installation
    else {
        return " update-test-trival/update-test-$q-$rpm{$d}{fn}.$arch.rpm";
    }
}

# Optionally skip exit status check in case immediate reboot is expected
sub trup_call {
    my $cmd   = shift;
    my $check = shift // 1;
    $cmd .= " > /dev/$serialdev";
    $cmd .= " ; echo trup-\$?- > /dev/$serialdev" if $check;

    script_run "transactional-update $cmd", 0;
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

# Install a pkg in Kubic
sub trup_install {
    my $input = shift;
    my ($unnecessary, $necessary);

    # rebootmgr has to be turned off as prerequisity for this to work
    script_run "rebootmgrctl set-strategy off";

    my @pkg = split(' ', $input);
    foreach (@pkg) {
        if (!script_run("rpm -q $_")) {
            $unnecessary .= "$_ ";
        }
        else {
            $necessary .= "$_ ";
        }
    }
    record_info "Skip", "Pre-installed (no action): $unnecessary" if $unnecessary;
    if ($necessary) {
        record_info "Install", "Installing: $necessary";
        trup_call("pkg install $necessary");
        process_reboot(1);
    }

    # By the end, all pkgs should be installed
    assert_script_run("rpm -q $input");
}
