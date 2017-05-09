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

use base "opensusebasetest";
use strict;
use testapi;
use lockapi;

sub run() {
    # Notify others that installation finished
    barrier_wait "WORKERS_INSTALLED";
    # Wait until controller node finishes
    barrier_wait "CNTRL_FINISHED";
}

sub post_run_hook {
    script_run "journalctl > journal.log";
    upload_logs "journal.log";

    script_run
      "docker exec -it \$(docker ps | grep velum-dashboard | awk '{print \$1}') bundle exec rails runner 'puts SaltEvent.all.to_json' > SaltEvents.log";
    upload_logs "SaltEvents.log";
}

1;
# vim: set sw=4 et:
