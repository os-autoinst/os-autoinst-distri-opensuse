# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Check that the maintenance updates of the following packages contain a trigger for restarting the update client
# - libsolv
# - libzypp
# - zypper
# - PackageKit
# Maintainer: Anna Minou <anna.minou@suse.com>
# Tags: poo#71443

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;

sub run {
    my $self = shift;
    select_serial_terminal;

    # Get the maintenance updates of the corresponding packages
    my $result = script_output q(zypper lp -a | awk -F\| '(/libsolv/||/libzypp/||/zypper/||/PackageKit/) && !/zypper-/ { gsub(/ /,""); print $2}');
    my @patch_array = split ' ', $result;

    # Check that the creation date of the updates is after the year of 2020
    foreach my $i (@patch_array) {
        my $creation_date = script_output("zypper info -t patch $i | grep Created");
        my @year = split ' ', $creation_date;
        if ($year[7] >= 2020) {
            # Check that the maintenance update contains a trigger for restart
            my $flag = script_output("zypper info -t patch $i | grep Interactive");
            my @year_date = split ' ', $flag;
            die "Trigger for restart is missing! See poo#71443" if ($year_date[2] != "restart");
        }
        else {
            record_info("The cases before 2020 are not tested", "$creation_date");
        }
    }
}

1;
