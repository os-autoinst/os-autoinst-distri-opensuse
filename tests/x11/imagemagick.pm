use base "opensusebasetest";
use testapi;

# for https://bugzilla.novell.com/show_bug.cgi?id=717871

sub run() {
    my $self = shift;
    x11_start_program("xterm");
    script_run("cd /tmp; mkdir img ; cd img");
    script_run("curl openqa.opensuse.org/opensuse/qatests/img.tar.gz | tar xz");
    script_run("ls;display *.png");
    for ( 1 .. 3 ) {
        send_key "spc";
        sleep 3;
        assert_screen 'test-imagemagick-1', 3;
    }
    send_key "alt-f4";    # close display
    send_key "alt-f4";    # close xterm
}

1;
# vim: set sw=4 et:
