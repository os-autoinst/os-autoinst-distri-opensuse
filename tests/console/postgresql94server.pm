# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    become_root;

    # install the postgresql94 server package
    script_run "zypper -n in postgresql94-server && echo 'postgresql94-server_installed' > /dev/$serialdev";
    die "postgresql94-server install failed" unless wait_serial "postgresql94-server_installed", 200;

    # start the postgresql94 service
    script_run "/etc/init.d/postgresql start && echo 'postgresql94_server_started' > /dev/$serialdev";
    die "postgresql94 server start failed" unless wait_serial "postgresql94_server_started", 200;

    # check the status
    script_run "/etc/init.d/postgresql status > /dev/$serialdev";
    die "postgresql94 server status failed" unless wait_serial "running", 200;

    script_run "exit";
}

1;
# vim: set sw=4 et:
