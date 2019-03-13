# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Check that health-check service works correctly
# Maintainer: Ciprian Cret <ccret@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use caasp;
use utils;
use power_action_utils qw(power_action);


sub get_btrfsid {
    my $btrfs_id = script_output("btrfs subvolume get-default /");
    $btrfs_id =~ /ID (\d+) gen/;
    $btrfs_id = $1;
    return $btrfs_id;
}

sub get_loggedid {
    my $logged_id = script_output("cat /var/lib/misc/health-check.state");
    $logged_id =~ /LAST_WORKING_BTRFS_ID=(\d+)/;
    $logged_id = $1;
    return $logged_id;
}

sub compare_id {
    my $btrfs_id = get_btrfsid;
    my $hc_id = get_loggedid;
    die "The current snapshot id does not match the one from the health-checker log" unless $hc_id == $btrfs_id;;
}

sub run {
    # run health-checker to make sure the current snapshot doesn't have issues
    validate_script_output("health-checker", sub { m/passed/ });

    # keep the current snapshot id and compare it to the logged one
    my $initial_id = get_btrfsid;
    compare_id;

    # update etcd.sh to force health-checker to fail
    type_string("transactional-update shell\n");
    type_string("cp /usr/lib/health-checker/etcd.sh /tmp/etcd_bk.sh\n");
    type_string("sed -i 's/exit 0/exit 1/g' /usr/lib/health-checker/etcd.sh\n");
    type_string("exit\n");

    # check that the changes applied and we have a new snapshot
    my $current_id = get_btrfsid;
    my $logged_id = get_loggedid;
    die "The current snapshot is not ahead of the logged one" unless $current_id > $logged_id;

    power_action('reboot');

    my $self = shift;
    $self->wait_boot;
    microos_login();

    my $final_id = get_btrfsid;
    die "health-checker does not rollback to the correct snapshot" unless $initial_id == $final_id;

    compare_id;

    # run health-checker again. If the rollback was correct the check should pass
    validate_script_output("health-checker", sub { m/passed/ });
}

sub post_fail_hook {
    # revert changes to etcd.sh and reboot
    if (script_output("ls /tmp | grep etcd_bk") =~ /etcd_bk/) {
        type_string("transactional-update shell");
        type_string("mv /tmp/etcd_bk.sh /usr/lib/health-checker/etcd.sh\n");
        type_string("exit\n");

    power_action('reboot');
    my $self = shift;
    $self->wait_boot;
    microos_login();
    }
}

1;
