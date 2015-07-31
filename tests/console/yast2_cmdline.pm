use base "console_yasttest";
use testapi;

sub run() {
    my $self = shift;

    become_root();
    # Install git
    script_run "zypper -n install git-core; echo \"zypper-git-\$?-\" > /dev/$serialdev";
    wait_serial "zypper-git-0-";

    $self->run_yast_cli_test('yast-network');
}

1;
# vim: set sw=4 et:
