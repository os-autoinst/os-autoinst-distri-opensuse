use base "basetest";
use bmwqemu;

# test for equivalent of bug https://bugzilla.novell.com/show_bug.cgi?id=598574
sub is_applicable() {
    return ( $envs->{BIGTEST} );
}

sub run() {
    my $self = shift;
    script_run('rpm -q wget');
    script_run('wget -O- -q www3.zq1.de/test.txt');
    assert_screen 'test-wget_ipv6-1', 3;
}

1;
# vim: set sw=4 et:
