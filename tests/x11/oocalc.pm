use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("oocalc", 6, { valid => 1 } );
    sleep 2;
    wait_still_screen;    # extra wait because oo sometimes appears to be idle during start
    assert_screen 'test-oocalc-1', 3;
    type_string "Hello World!\n";
    sleep 2;
    assert_screen 'test-oocalc-2', 3;
    send_key "alt-f4";
    sleep 2;
    assert_screen 'test-oocalc-3', 3;
    assert_and_click 'dont-save-libreoffice-btn'; # _Don't save
}

sub ocr_checklist() {
    [

        #                {screenshot=>2, x=>104, y=>201, xs=>380, ys=>150, pattern=>"H ?ello", result=>"OK"}
    ];
}

1;
# vim: set sw=4 et:
