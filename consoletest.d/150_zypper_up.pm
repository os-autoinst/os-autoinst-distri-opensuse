use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;

    become_root();

    # Killall is used here, make sure that is installed
    script_run("zypper -n -q in psmisc");

    script_run("killall gpk-update-icon kpackagekitsmarticon packagekitd");
    if ( !$envs->{NET} && !$envs->{TUMBLEWEED} && !$envs->{EVERGREEN} && $envs->{SUSEMIRROR} ) {

        # non-NET installs have only milestone repo, which might be incompatible.
        my $repourl = 'http://' . $envs->{SUSEMIRROR};
        unless ( $envs->{FULLURL} ) {
            $repourl = $repourl . "/repo/oss";
        }
        script_run("zypper ar $repourl Factory");
    }
    $self->take_screenshot;
    script_run("zypper patch -l && echo 'worked' > /dev/$serialdev");
    my $ret = assert_screen( [qw/test-zypper_up-confirm test-zypper_up-nothingtodo/] );
    if ( $ret->{needle}->has_tag("test-zypper_up-confirm") ) {
        send_key "y\n";
    }
    waitserial( "worked", 700 ) || die "zypper failed";
    script_run("zypper patch -l && echo 'worked' > /dev/$serialdev");    # first one might only have installed "update-test-affects-package-manager"
    if ( check_screen "test-zypper_up-confirm" ) {
        type_string "y\n";
    }
    waitserial( "worked", 700 ) || die "zypper failed";
    script_run( "rpm -q libzypp zypper", 0 );
    check_screen  "rpm-q-libzypp", 5 ;
    $self->take_screenshot;

    # XXX: does this below make any sense? what if updates got
    # published meanwhile?
    send_key "ctrl-l";    # clear screen to see that second update does not do any more
    script_run( "zypper -n -q patch", 0 );
    script_run('echo $?');
    script_run('exit');
    assert_screen 'test-zypper_up-1', 3;
}

sub test_flags() {
    return { 'milestone' => 1 };
}

1;
# vim: set sw=4 et:
