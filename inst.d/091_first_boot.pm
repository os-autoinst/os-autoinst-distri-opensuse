
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

    # old code likely to not work at all
    #	local $ENV{SCREENSHOTINTERVAL}=$ENV{SCREENSHOTINTERVAL}*3;
    #
    #	# read sub-stages of automaticconfiguration
    #	set_ocr_rect(240,256,530,100);
    #	# waitforneedle("users-booted", 180);
    #	set_ocr_rect();
    #	my $img=getcurrentscreenshot();
    #	my $ocr=ocr::get_ocr($img, "-l 200", [250,100,600,500]);
    #	diag "post-install-ocr: $ocr";
    #	if($ocr=~m/Installation of package .* failed/i or checkneedle("install-failed", 1)) {
    #		sendkeyw "alt-d"; # see details of failure
    #		if(1) { # ignore
    #			$self->take_screenshot; sleep 2;
    #			sendkeyw "alt-i";
    #			sendkey "ret";
    #			waitstillimage(50,900);
    #		} else {
    #			alarm 3; # end here as we can not continue
    #		}
    #	}

    if ( $ENV{'NOAUTOLOGIN'} ) {
        waitforneedle( 'displaymanager', 200 );
        sendautotype($username);
        sendkey("ret");
        sendautotype("$password");
        sendkey("ret");
    }

    # Check for errors during first boot
    my $err = 0;
    my @tags = qw/desktop-at-first-boot install-failed kde-greeter/;
    while (1) {
        my $ret = waitforneedle( \@tags, 200 );
        last if $ret->{needle}->has_tag("desktop-at-first-boot");
	if ($ret->{needle}->has_tag("kde-greeter")) {
   	  sendkey "esc";
	  @tags = grep { $_ ne 'kde-greeter' } @tags;
	  next;
	}
        $self->take_screenshot;
        sleep 2;
        sendkey "ret";
        $err = 1;
    }

    mydie if $err;
}

sub test_flags() {
    return { 'important' => 1, 'fatal' => 1, 'milestone' => 1 };
}

1;
# vim: set sw=4 et:
