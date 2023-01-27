# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: First installation using D-Installer current CLI (only for development purpose)
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;

use testapi;
use utils;

sub run {
    script_start_io('dinstallerctl install');
    wait_serial('Do you want to start the installation?')
      or die 'Confirmation dialog not shown';
    type_string("y\n");
    my $ret = script_finish_io(timeout => 1200);
    die "dinstallerctl install didn't finish" unless defined($ret);
}

1;
