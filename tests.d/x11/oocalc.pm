use base "x11step";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$vars{NICEVIDEO} && $vars{DESKTOP} =~ /kde|gnome/ && !$vars{LIVECD};
}

sub run() {
    my $self = shift;
    x11_start_program("oocalc");
    sleep 2;
    waitstillimage;    # extra wait because oo sometimes appears to be idle during start
    assert_screen 'test-oocalc-1', 3;
    type_string "Hello World!\n";
    sleep 2;
    assert_screen 'test-oocalc-2', 3;
    send_key "alt-f4";
    sleep 2;
    assert_screen 'test-oocalc-3', 3;
    send_key "alt-w";
    sleep 2;           # _w_ithout saving
}

sub ocr_checklist() {
    [

        #                {screenshot=>2, x=>104, y=>201, xs=>380, ys=>150, pattern=>"H ?ello", result=>"OK"}
    ];
}

1;
# vim: set sw=4 et:
