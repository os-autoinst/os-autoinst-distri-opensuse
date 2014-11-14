use base "consolestep";
use bmwqemu;

sub run() {
    my $self = shift;

    become_root();
    type_string "PS1=\"# \"\n";

    # Killall is used here, make sure that is installed
    script_run("zypper -n -q in psmisc");

    script_run("killall gpk-update-icon kpackagekitsmarticon packagekitd");
    $self->take_screenshot;

    script_run("zypper patch -l; echo zypper-patch-1-status-\$? > /dev/$serialdev");
    my $ret = assert_screen( [qw/test-zypper_up-confirm test-zypper_up-nothingtodo/] );
    if ( $ret->{needle}->has_tag("test-zypper_up-confirm") ) {
        send_key "y\n";
    }
    wait_serial( "zypper-patch-1-status-0", 700 ) || die "zypper failed";
    script_run("zypper patch -l; echo zypper-patch-2-status-\$? > /dev/$serialdev");    # first one might only have installed "update-test-affects-package-manager"
    if ( check_screen("test-zypper_up-confirm") ) {
        type_string "y\n";
    }
    wait_serial( "zypper-patch-2-status-0", 700 ) || die "zypper failed";

    script_run('exit');
    script_run( "rpm -q libzypp zypper", 0 );
    save_screenshot;
}

sub test_flags() {
    return { 'milestone' => 1 };
}

1;
