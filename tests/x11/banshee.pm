use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    x11_start_program("banshee");
    assert_screen 'test-banshee-1', 3;
    send_key "ctrl-q";    # really quit (alt-f4 just backgrounds)
    send_key "alt-f4";
    wait_idle;
}

sub ocr_checklist() {
    [

        { screenshot => 1, x => 8, y => 150, xs => 140, ys => 380, pattern => "(?si:Vide.s.*Fav.rites.*Unwatched)", result => "OK" }
    ];
}

1;
