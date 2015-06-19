use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    become_root;

    # install the postgresql94 client package
    script_run "zypper -n in postgresql94 && echo 'postgresql94_installed' > /dev/$serialdev";
    die "postgresql94 install failed" unless wait_serial "postgresql94_installed", 200;

    # check the postgresql94 client
    script_run "/usr/bin/psql --help && echo 'postgresql94_client_started' > /dev/$serialdev";
    die "postgresql94 client failed" unless wait_serial "postgresql94_client_started", 200;

    script_run "exit";
}

1;
# vim: set sw=4 et:
