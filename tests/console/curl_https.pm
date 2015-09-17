use base "consoletest";
use testapi;

# test for bug https://bugzilla.novell.com/show_bug.cgi?id=598574
sub run() {
    my $self = shift;
    validate_script_output('curl -v https://eu.httpbin.org/get 2>&1',
                           sub { m,subjectAltName: eu.httpbin.org matched, });
}

1;
# vim: set sw=4 et:
