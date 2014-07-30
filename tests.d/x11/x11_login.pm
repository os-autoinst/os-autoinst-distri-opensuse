use base "x11step";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && ( $vars{NOAUTOLOGIN} || $vars{XDMUSED} );
}

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
