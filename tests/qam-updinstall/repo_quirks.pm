# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFA
# Maintainer: qe-core <qe-core@suse.de>, qe-sap <qe-sap@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

sub run{
    my $self = @_;
    select_serial_terminal();
    zypper_call(q{mr -d $(zypper lr | awk -F '|' '/NVIDIA/ {print $2}')}, exitcode => [0, 3]);autotest::loadtest("tests/qam-updinstall/repo_quirks.pm");
    zypper_call(q{mr -f $(zypper lr | awk -F '|' '/SLES15-SP4-15.4-0/ {print $2}')}, exitcode => [0, 3]) if get_var('FLAVOR') =~ /TERADATA/;
    zypper_call("ar -f http://dist.suse.de/ibs/SUSE/Updates/SLE-Live-Patching/12-SP3/" . get_var('ARCH') . "/update/ sle-module-live-patching:12-SP3::update") if is_sle('=12-SP3');
}

1;
