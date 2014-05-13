# XXX what is this test meant to be about?
# workaround for software conflicts?
#
#!/usr/bin/perl -w
use strict;
use base "installstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return 0;    # FIXME
    return $self->SUPER::is_applicable && !$envs->{LIVECD};
}

sub ocrconflict() {
    my $img = getcurrentscreenshot();
    my $ocr = ocr::get_ocr( $img, "-l 200", [ 250, 100, 700, 600 ] );
    return 1 if ( $ocr =~ m/can.*solve/i );
    return 1 if ( $ocr =~ m/dependencies automatically/i );
    return 0;
}

sub run() {
    my $self = shift;
    if ( $envs->{DOCRUN} || check_screen  "software-conflict", 1  || ocrconflict ) {
        $cmd{software} = "alt-s" if $envs->{VIDEOMODE} eq "text";
        send_key $cmd{change};      # Change
        send_key $cmd{software};    # Software
        waitidle;
        for ( 1 .. 3 ) {
            send_key "down";
        }
        sleep 4;
	assert_screen 'test-change_software-toaccept', 3;
        send_key $cmd{accept};      # Accept
        sleep 2;
        send_key "alt-o";           # cOntinue
        waitidle;
    }
}

1;
# vim: set sw=4 et:
