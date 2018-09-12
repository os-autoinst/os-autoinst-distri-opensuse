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

# Set password on autoyast nodes - bsc#1030876
sub set_autoyast_password {
    script_run 'id=$(docker ps | grep salt-master | awk \'{print $1}\')';
    script_run 'pw=$(python -c "import crypt; print crypt.crypt(\'nots3cr3t\', \'\$6\$susetest\')")';
    script_run 'docker exec $id salt -E ".{32}" shadow.set_password root "$pw"', 60;

    # Unlock and wait for propagation
    unpause 'AUTOYAST_PW_SET';
    sleep 30 if is_caasp('local');
}

sub run() {
    # Admin node needs long time to start web interface - bsc#1031682
    script_retry 'curl -kLI localhost | grep _velum_session', retry => 15, delay => 15;
    unpause 'VELUM_STARTED';

    # Download update script
    assert_script_run 'curl -O ' . data_url("caasp/update.sh");
    assert_script_run 'chmod +x update.sh';

    # Wait during tests from controller
    pause_until 'CNTRL_FINISHED';

    # Login if node was rebooted (update|reboot modules)
    if (check_screen 'linux-login-casp', 0) {
        reset_consoles;
        select_console 'root-console';
    }

    set_autoyast_password if is_caasp 'DVD';
    export_cluster_logs;
}

sub post_fail_hook {
    # Variable to enable failed cluster debug
    sleep if check_var('DEBUG_SLEEP', 'admin');
    export_cluster_logs;
}

1;
