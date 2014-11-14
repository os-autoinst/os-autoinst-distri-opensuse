use base "consolestep";
use bmwqemu;

# test for equivalent of bug https://bugzilla.novell.com/show_bug.cgi?id=
sub run() {
    my $self = shift;
    script_run('test -L /etc/mtab && echo OK || echo fail');
    assert_screen "test-mtab-1", 3;
    script_run('cat /etc/mtab');
    save_screenshot;
}

1;
# vim: set sw=4 et:
