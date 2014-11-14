use base "x11step";
use bmwqemu;

sub run() {
    my $self = shift;

    # log in
    type_string $username. "\n";
    sleep 1;
    type_string $password. "\n";
    wait_idle;
}

1;
# vim: set sw=4 et:
