# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: First installation using D-Installer current CLI (only for development purpose)
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;

use testapi;
use utils;
use power_action_utils qw(power_action);

sub run {
    $testapi::password = 'linux';

    assert_screen('suse-alp-containerhost-os', 120);

    select_console('root-console');

    assert_script_run('dinstallerctl rootuser password nots3cr3t');

    script_start_io('dinstallerctl install');
    wait_serial('Do you want to start the installation?')
      or die 'Confirmation dialog not shown';
    type_string("y\n");
    my $ret = script_finish_io(timeout => 60000);
    die "dinstallerctl install didn't finish" unless defined($ret);

    power_action('reboot', textmode => 1);

    $testapi::password = 'nots3cr3t';
}

1;
