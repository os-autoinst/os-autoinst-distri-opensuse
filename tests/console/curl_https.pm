use base "consoletest";
use testapi;

# test for bug https://bugzilla.novell.com/show_bug.cgi?id=598574
sub run() {
    my $self = shift;
    validate_script_output('curl -v https://www.opensuse.org',
                           sub { m,Location: http://www.opensuse.org/en/, });
}

1;
# vim: set sw=4 et:
