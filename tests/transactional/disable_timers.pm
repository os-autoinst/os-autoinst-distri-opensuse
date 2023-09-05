# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Disable various timers that sometimes cause test interruptions
# Maintainer: qa-c team <qa-c@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils qw(systemctl);
use mm_network qw(is_networkmanager);
use version_utils qw(is_microos is_sle_micro);
use serial_terminal;

sub run {
    my ($self) = @_;

    select_serial_terminal;

    # Disable disruptive timers
    my @timers = qw(snapper-cleanup.timer fstrim.timer transactional-update.timer btrfs-balance.timer btrfs-defrag.timer btrfs-scrub.timer btrfs-trim.timer);
    push(@timers, "snapper-timeline.timer") unless (is_microos);
    push(@timers, "transactional-update-cleanup.timer") if (is_sle_micro(">5.1"));
    foreach my $timer (@timers) {
        systemctl("disable --now '$timer'");
    }
}

1;
