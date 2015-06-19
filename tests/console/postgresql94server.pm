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
