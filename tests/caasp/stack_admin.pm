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
use lockapi;
use caasp;
use version_utils 'is_caasp';

# Set default password on worker nodes - bsc#1030876
sub set_autoyast_password {
    my $name = shift;
    mutex_lock $name;
    mutex_unlock $name;
    script_run 'id=$(docker ps | grep salt-master | awk \'{print $1}\')';
    script_run 'pw=$(python -c "import crypt; print crypt.crypt(\'nots3cr3t\', \'\$6\$susetest\')")';
    script_run 'docker exec $id salt -E ".{32}" shadow.set_password root "$pw"';
}

# Handle update process
sub handle_update {
    # Download update script
    assert_script_run 'curl -O ' . data_url("caasp/update.sh");
    assert_script_run 'chmod +x update.sh';

    # Wait until update is finished
    mutex_lock 'UPDATE_FINISHED';
    mutex_unlock 'UPDATE_FINISHED';

    # Admin node was rebooted
    reset_consoles;
    select_console 'root-console';
}

sub run() {
    # Admin node needs long time to start web interface - bsc#1031682
    # Wait in loop until velum is available until controller node can connect
    my $timeout   = 240;
    my $starttime = time;
    while (script_run 'curl -kLI localhost | grep velum') {
        my $timerun = time - $starttime;
        if ($timerun < $timeout) {
            sleep 15;
        }
        else {
            die "Velum did not start in $timeout seconds";
        }
    }
    # Controller node can connect to velum
    mutex_create "VELUM_STARTED";

    set_autoyast_password 'NODES_ACCEPTED'         if is_caasp 'DVD';
    handle_update                                  if update_scheduled;
    set_autoyast_password 'DELAYED_NODES_ACCEPTED' if is_caasp('DVD') && get_delayed_worker;

    # Wait until controller node finishes
    mutex_lock "CNTRL_FINISHED";
    mutex_unlock "CNTRL_FINISHED";

    export_cluster_logs;
}

sub post_fail_hook {
    # Variable to enable failed cluster debug
    sleep if check_var('DEBUG_SLEEP', 'admin');

    script_run "journalctl > journal.log";
    upload_logs "journal.log";

    script_run 'supportconfig -i psuse_caasp -B supportconfig', 120;
    upload_logs '/var/log/nts_supportconfig.tbz';
}

1;
# vim: set sw=4 et:
