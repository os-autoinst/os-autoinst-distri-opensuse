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
    send_key "alt-d";
    sleep 2;

    send_key "alt-l", 1;    # enable LVM-based proposal
    if ( $ENV{ENCRYPT} ) {
        send_key "alt-y", 1;
        waitforneedle("inst-encrypt-password-prompt");
        sendpassword;
        send_key "tab";
        sendpassword;
        send_key "ret", 1;
        waitforneedle( "partition-cryptlvm-summary", 3 );
    }
    else {
        waitforneedle( "partition-lvm-summary", 3 );
    }
    waitidle 5;
    send_key "alt-o";
}

1;
# vim: set sw=4 et:
