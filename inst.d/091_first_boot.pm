
use strict;
use base "installstep";
use bmwqemu;

sub run() {
    my $self = shift;

    if ( $ENV{ENCRYPT} ) {
        wait_encrypt_prompt;
    }

    #if($ENV{RAIDLEVEL} && !$ENV{LIVECD}) { do "$scriptdir/workaround/656536.pm" }
    #waitforneedle "automaticconfiguration", 70;
    mouse_hide();

    if ( $ENV{'NOAUTOLOGIN'} ) {
        waitforneedle( 'displaymanager', 200 );
        sendautotype($username);
        send_key "ret";
        sendautotype("$password");
        send_key "ret";
    }

    # Check for errors during first boot
    my $err = 0;
    my @tags = qw/desktop-at-first-boot install-failed kde-greeter/;
    while (1) {
        my $ret = waitforneedle( \@tags, 200 );
        last if $ret->{needle}->has_tag("desktop-at-first-boot");
	if ($ret->{needle}->has_tag("kde-greeter")) {
   	  send_key "esc";
	  @tags = grep { $_ ne 'kde-greeter' } @tags;
	  push(@tags, "drkonqi-crash");
	  next;
	}
        if ($ret->{needle}->has_tag("drkonqi-crash")) {
          send_key "alt-d";
	  # maximize
	  send_key "alt-shift-f3";
	  sleep 8;
	  $self->take_screenshot;
	  send_key "alt-c";
          @tags = grep { $_ ne 'drkonqi-crash' } @tags;
          next;
        }

        $self->take_screenshot;
        sleep 2;
        send_key "ret";
        $err = 1;
    }

    mydie if $err;
}

sub test_flags() {
    return { 'important' => 1, 'fatal' => 1, 'milestone' => 1 };
}

1;
# vim: set sw=4 et:
