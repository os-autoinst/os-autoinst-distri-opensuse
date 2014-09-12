use base "installzdupstep";
use strict;
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && $vars{ZDUP};
}

sub run() {
    my $self = shift;
    $vars{ZDUPREPOS} ||= "http://$vars{SUSEMIRROR}";
    send_key "ctrl-l";

    # Disable all repos, so we do not need to remove one by one
    script_sudo("zypper modifyrepo --all --disable");

    my $nr = 1;
    foreach my $r ( split( /\+/, $vars{ZDUPREPOS} ) ) {
        script_sudo("zypper addrepo $r repo$nr");
        $nr++;
    }
    script_sudo("zypper --gpg-auto-import-keys refresh");

    script_sudo("zypper dup -l");
    
    my $ret = assert_screen [qw/zypper-dup-continue zypper-dup-conflict/], 5;
    while ( $ret->{needle}->has_tag("zypper-dup-conflict") ) {
        send_key "1", 1;
        send_key "ret", 1;
	$ret = assert_screen [qw/zypper-dup-continue zypper-dup-conflict/], 5;
    }

    if ( $ret->{needle}->has_tag("zypper-dup-continue") ) {
	send_key "y", 1;
        send_key "ret", 1;
    }

    $ret = assert_screen [qw/zypper-dup-error zypper-dup-finish zypper-dup-retrieving zypper-dup-installing/], 5;
    while ( $ret->{needle}->has_tag("zypper-dup-retrieving") || $ret->{needle}->has_tag("zypper-dup-installing")) {
	last if check_screen [qw/zypper-dup-error "zypper-dup-finish/];
	send_key "shift", 1;
	sleep 10;
	$ret = assert_screen [qw/zypper-dup-error zypper-dup-error zypper-dup-finish zypper-dup-retrieving zypper-dup-installing/], 10;
    }

    assert_screen "zypper-dup-finish", 2;

    sleep 2;
    send_key "ctrl-alt-f4";
    sleep 3;
}

1;
# vim: set sw=4 et:
