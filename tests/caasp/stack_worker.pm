# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Start worker nodes
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "caasp_clusternode";
use strict;
use testapi;
use lockapi 'barrier_wait';
use autotest 'query_isotovideo';
use version_utils 'is_caasp';
use caasp;

# Updated from incident repo before adding to cluster
sub incident_repo_dup {
    my $repo = get_required_var('INCIDENT_REPO');
    assert_script_run 'echo -e "[main]\nvendors = suse,opensuse,obs://build.suse.de,obs://build.opensuse.org" > /etc/zypp/vendors.d/vendors.conf';
    assert_script_run "zypper ar --refresh --no-gpgcheck $repo UPDATE";
    assert_script_run 'zypper lr -U';
    assert_script_run 'transactional-update cleanup dup', 300;
    process_reboot 1;
}

sub run {
    # Enable salt debug
    if (get_var('DEBUG_SLEEP') && !get_var('AUTOYAST')) {
        script_run 'echo "log_level: trace" >> /etc/salt/minion';
        script_run 'systemctl restart salt-minion';
    }
    # Notify others that installation finished
    if (get_var 'DELAYED') {
        incident_repo_dup if is_caasp('qam');
        barrier_wait 'DELAYED_NODES_ONLINE';
    }
    else {
        barrier_wait "NODES_ONLINE";
    }
    pause_until 'CNTRL_FINISHED';

    # Some nodes were removed & powered off during test run
    return if query_isotovideo('backend_is_shutdown');

    # Wait until password is set from admin node
    pause_until('AUTOYAST_PW_SET') if get_var('AUTOYAST');

    # Redraw login screen
    send_key 'ret';

    # Node could be rebooted during stack tests
    if (check_screen 'linux-login-casp', 7) {
        reset_consoles;
        select_console 'root-console';
    }
}

1;
