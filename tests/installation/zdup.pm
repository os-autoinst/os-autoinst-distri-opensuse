use base "installbasetest";
use strict;
use testapi;

sub run() {
    my $self = shift;
    my $defaultrepo = "http://" . get_var("SUSEMIRROR");

    # Disable all repos, so we do not need to remove one by one
    script_run("zypper modifyrepo --all --disable");

    my $nr = 1;
    foreach my $r ( split( /\+/, get_var("ZDUPREPOS", $defaultrepo) ) ) {
        script_run("zypper addrepo $r repo$nr");
        $nr++;
    }
    script_run("zypper --gpg-auto-import-keys refresh");

    script_run("zypper dup -l");

    my $ret = assert_screen [qw/zypper-dup-continue zypper-dup-conflict/], 10;
    while ( $ret->{needle}->has_tag("zypper-dup-conflict") ) {
        send_key "1", 1;
        send_key "ret", 1;
        $ret = assert_screen [qw/zypper-dup-continue zypper-dup-conflict/], 5;
    }

    if ( $ret->{needle}->has_tag("zypper-dup-continue") ) {
        send_key "y", 1;
        send_key "ret", 1;
    }

    my @tags = qw/zypper-dup-retrieving zypper-dup-installing zypper-view-notifications zypper-post-scripts zypper-dup-agreeing/;
    $ret = assert_screen \@tags, 5;
    while ( defined($ret) ) {
        last if check_screen [qw/zypper-dup-error zypper-dup-finish/];
        if ( $ret->{needle}->has_tag("zypper-view-notifications") ) {
            send_key "n", 1; # do not show notifications
            send_key "ret", 1;
        }
        send_key "shift", 1;
        sleep 10;
        $ret = assert_screen \@tags, 10;
    }

    assert_screen "zypper-dup-finish", 2;
}

1;
# vim: set sw=4 et:
