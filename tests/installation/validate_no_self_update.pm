# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Validate installer self update is not attempted when explicitly disabled
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;
    select_console('install-shell');
    assert_script_run('test -z "$(ls -A /download | grep yast_)"',
        fail_message => '/download directory contains updates, expected not to contain any yast_* files');
    assert_script_run('! grep /var/log/YaST2/y2log -e "Trying installer update"',
        fail_message => 'YaST logs contain entry that self update was attempted, but is explicitly disabled');
    select_console('installation');
}

1;
