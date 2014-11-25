use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("oowriter");
    assert_screen 'test-ooffice-1', 10;
    type_string "Hello World!";
    assert_screen 'test-ooffice-2', 5;
    send_key "alt-f4";
    assert_screen "ooffice-save-prompt", 8;
    send_key "alt-w"; # *W*ithout saving
}

1;
# vim: set sw=4 et:
