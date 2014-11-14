package serverstep;
use base "consolestep";

# Use this class for server tests

sub is_applicable() {
    return serverstep_is_applicable;
}

1;
# vim: set sw=4 et:
