use base "basetest";
use bmwqemu;

sub is_applicable() {
    return $ENV{LVM};
}

sub run() {
    my $self = shift;

    # workaround for new style
    my $closedialog;
    my $ret = waitforneedle( [ 'partioning-edit-proposal-button' ], 40 );
    sendkey "alt-d";
    sleep 2;

    sendkeyw "alt-l";    # enable LVM-based proposal
    if ( $ENV{ENCRYPT} ) {
        sendkeyw "alt-y";
        waitforneedle("inst-encrypt-password-prompt");
        sendpassword;
        sendkey "tab";
        sendpassword;
        sendkeyw "ret";
        waitforneedle( "partition-cryptlvm-summary", 3 );
    }
    else {
        waitforneedle( "partition-lvm-summary", 3 );
    }
    waitidle 5;
    sendkey "alt-o";
}

1;
# vim: set sw=4 et:
