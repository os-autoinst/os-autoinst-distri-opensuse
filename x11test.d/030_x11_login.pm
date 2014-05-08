use base "basetest";
use bmwqemu;

sub is_applicable() {
    return $ENV{NOAUTOLOGIN} || $ENV{XDMUSED};
}

sub run() {
    my $self = shift;

    # log in
    type_string $username. "\n";
    sleep 1;
    type_string $password. "\n";
    waitidle;
}

1;
# vim: set sw=4 et:
