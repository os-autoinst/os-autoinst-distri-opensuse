# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Start admin node (velum)
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use caasp;
use version_utils 'is_caasp';

# Set default password on worker nodes - bsc#1030876
sub set_autoyast_password {
    script_run 'id=$(docker ps | grep salt-master | awk \'{print $1}\')';
    script_run 'pw=$(python -c "import crypt; print crypt.crypt(\'nots3cr3t\', \'\$6\$susetest\')")';
    script_run 'docker exec $id salt -E ".{32}" shadow.set_password root "$pw"';
}

# Handle update process
sub handle_update_reboot {
    # Download update script
    assert_script_run 'curl -O ' . data_url("caasp/update.sh");
    assert_script_run 'chmod +x update.sh';

    pause_until 'REBOOT_FINISHED';

    # Admin node was rebooted only if update passed
    if (check_screen 'linux-login-casp', 0) {
        reset_consoles;
        select_console 'root-console';
    }
}

sub run() {
    # Admin node needs long time to start web interface - bsc#1031682
    script_retry 'curl -kLI localhost | grep _velum_session', retry => 15, delay => 15;
    unpause 'VELUM_STARTED';

    # Set password for autoyast cluster nodes
    if (is_caasp 'DVD') {
        pause_until 'NODES_ACCEPTED';
        set_autoyast_password;
    }

    handle_update_reboot;

    # Set password for autoyast cluster nodes
    if (is_caasp('DVD') && get_delayed_worker) {
        pause_until 'DELAYED_NODES_ACCEPTED';
        set_autoyast_password;
    }

    pause_until 'CNTRL_FINISHED';
    export_cluster_logs;
}

sub post_fail_hook {
    # Variable to enable failed cluster debug
    sleep if check_var('DEBUG_SLEEP', 'admin');
    export_cluster_logs;
}

1;
