package caasp_clusternode;
use base "opensusebasetest";

use strict;
use testapi;
use version_utils 'is_caasp';
use autotest 'query_isotovideo';

# Export logs from cluster admin/workers
sub export_cluster_logs {
    if (is_caasp 'local') {
        record_info 'Logs skipped', 'Log export skipped because of LOCAL DEVENV';
    }
    else {
        script_run "journalctl > journal.log", 60;
        upload_logs "journal.log";

        script_run 'supportconfig -b -B supportconfig', 500;
        upload_logs '/var/log/nts_supportconfig.tbz';

        upload_logs('/var/log/transactional-update.log', failok => 1);
        upload_logs('/var/log/YaST2/y2log-1.gz') if get_var 'AUTOYAST';
    }
}

# Requested by SCC team
sub deregister {
    if (get_var('REGISTER')) {
        assert_script_run 'SUSEConnect --status-text | tee /dev/tty | grep -q "Status: ACTIVE"';
        assert_script_run 'test -f /etc/zypp/credentials.d/SCCcredentials';
        assert_script_run 'SUSEConnect -d';
    } else {
        # For sneaky autoyast nodes
        script_run 'SUSEConnect -d';
    }
}

sub post_run_hook {
    # Some nodes were removed & powered off during test run
    return if query_isotovideo('backend_is_shutdown');

    export_cluster_logs;
    deregister;
}

sub post_fail_hook {
    if (check_var('STACK_ROLE', 'admin')) {
        sleep if check_var('DEBUG_SLEEP', 'admin');
        export_cluster_logs;
    }
    deregister;
}

1;
