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

# Set default password on worker nodes
sub workaround_bsc_1030876 {
    mutex_lock "NODES_ACCEPTED";
    script_run 'id=$(docker ps | grep salt-master | awk \'{print $1}\')';
    script_run 'pw=$(python -c "import crypt; print crypt.crypt(\'nots3cr3t\', \'\$6\$susetest\')")';
    script_run 'docker exec $id salt -E ".{32}" shadow.set_password root "$pw"';
}

sub export_logs {
    script_run 'docker ps';
    save_screenshot;

    script_run "journalctl > journal.log", 60;
    upload_logs "journal.log";

    script_run 'velumid=$(docker ps | grep velum-dashboard | awk \'{print $1}\')';
    my $railscmd = 'entrypoint.sh bundle exec rails';

    script_run "docker exec -it \$velumid $railscmd runner 'puts SaltEvent.all.to_yaml' > SaltEvents.yml";
    upload_logs "SaltEvents.yml";

    script_run "docker exec -it \$velumid $railscmd runner 'puts Pillar.all.to_yaml' > Pillar.yml";
    upload_logs "Pillar.yml";
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
    workaround_bsc_1030876;

    # Wait until controller node finishes
    mutex_lock "CNTRL_FINISHED";
    mutex_unlock "CNTRL_FINISHED";

    export_logs;
}

1;
# vim: set sw=4 et:
