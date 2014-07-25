use base "installbasetest";
use strict;
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && $vars{ZDUP};
}

sub run() {
    my $self = shift;
    $vars{ZDUPREPOS} ||= "http://$vars{SUSEMIRROR}/repo/oss/";
    send_key "ctrl-l";
    script_sudo("killall gpk-update-icon packagekitd");
    unless ( $vars{EVERGREEN} ) {
        script_sudo("zypper modifyrepo --all --disable");
    }
    if ( $vars{TUMBLEWEED} ) {
        script_sudo("zypper ar --refresh http://widehat.opensuse.org/distribution/openSUSE-current/repo/oss/ 'openSUSE Current OSS'");
        script_sudo("zypper ar --refresh http://widehat.opensuse.org/distribution/openSUSE-current/repo/non-oss/ 'openSUSE Current non-OSS'");
        script_sudo("zypper ar --refresh http://widehat.opensuse.org/update/openSUSE-current/ 'openSUSE Current Update'");
    }
    if ( $vars{EVERGREEN} ) {
        script_sudo("mkdir /etc/zypp/vendors.d");
        type_string(
            "sudo dd of=/etc/zypp/vendors.d/evergreen <<EOF
[main]
vendors = openSUSE Evergreen,suse,opensuse
EOF\n"
        );
    }
    my $nr = 1;
    foreach my $r ( split( /\+/, $vars{ZDUPREPOS} ) ) {
        script_sudo("zypper addrepo $r repo$nr");
        $nr++;
    }
    script_sudo("zypper --gpg-auto-import-keys refresh");
    script_sudo("zypper dup -l");
    assert_screen 'test-zdup-1', 3;

    for ( 1 .. 20 ) {
        send_key "2";    # ignore unresolvable
        send_key "ret", 1;
    }
    type_string "1\n";    # some conflicts can not be ignored
    assert_screen 'test-zdup-2', 3;
    type_string "y\n";    # confirm
    local $vars{SCREENSHOTINTERVAL} = 2.5;
    for ( 1 .. 12 ) {
        sleep 60;
        send_key "shift";    # prevent console screensaver
    }
    for ( 1 .. 12 ) {
        waitstillimage( 60, 66 ) || send_key "shift";    # prevent console screensaver
    }
    waitstillimage( 60, 5000 );                         # wait for upgrade to finish

    assert_screen 'test-zdup-3', 3;
    sleep 2;
    send_key "ctrl-alt-f4";
    sleep 3;

    type_string "n\n";                                 # don't view notifications
}

1;
# vim: set sw=4 et:
