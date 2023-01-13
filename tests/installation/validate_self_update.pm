# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Validate installer self update feature downloads updates and applies
#          them to the system
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;
    select_console('install-shell');
    my $self_update_repo = get_required_var('INSTALLER_SELF_UPDATE');
    assert_script_run("zgrep '$self_update_repo' /var/log/YaST2/y2log*",
        fail_message => 'Expected to have log entries that self update repo was contacted');
    assert_script_run('test -n "$(ls -A /download | grep yast_)"',
        fail_message => '/download is expected to contain downloaded updates, no yast_* files found');
    assert_script_run('mount | grep -P "/download/yast_\d+"',
        fail_message => 'updates are not mounted, expected /download/yast_* to be mounted as /mount/yast_*');
    select_console('installation');
}

1;
