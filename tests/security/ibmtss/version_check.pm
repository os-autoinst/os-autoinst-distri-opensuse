# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Update IBM's Trusted Computing Group Software Stack (TSS) to the latest version.
#          IBM has tested x86_64, s390x and ppc64le, we only need cover aarch64
# Maintainer: QE Security <none@suse.de>
# Tags: poo#101088, poo#102792, poo#104208 tc#1769800

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call package_upgrade_check);

sub run {
    my $self = shift;
    select_serial_terminal;

    # Version check
    my $pkg_list = {ibmtss => '1.6.0'};
    zypper_call("in " . join(' ', keys %$pkg_list));
    package_upgrade_check($pkg_list);
}

1;
