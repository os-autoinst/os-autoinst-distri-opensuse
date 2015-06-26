use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    become_root();

    script_run("zypper patch -l; echo 'worked-patch-\$?' > /dev/$serialdev");
    my $ret = assert_screen( [qw/test-zypper_up-confirm test-zypper_up-nothingtodo/] );
    if ( $ret->{needle}->has_tag("test-zypper_up-confirm") ) {
        type_string "y\n";
    }
    $ret = wait_serial "worked-patch-\?-", 700;
    $ret =~ /worked-patch-(\d+)/;
    die "zypper failed with code $1" unless $1 == 0 || $1 == 102 || $1 == 103;

    script_run("zypper patch -l; echo 'worked-2-patch-\$?-' > /dev/$serialdev");    # first one might only have installed "update-test-affects-package-manager"
    $ret = assert_screen [qw/test-zypper_up-confirm test-zypper_up-nothingtodo/];
    if ( $ret && $ret->{needle}->has_tag("test-zypper_up-confirm") ) {
        type_string "y\n";
    }
    $ret = wait_serial "worked-2-patch-\?-", 1500;
    $ret =~ /worked-2-patch-(\d+)/;
    die "zypper failed with code $1" unless $1 == 0 || $1 == 102;

    assert_script_run("rpm -q libzypp zypper");

    # XXX: does this below make any sense? what if updates got
    # published meanwhile?
    send_key "ctrl-l";    # clear screen to see that second update does not do any more
    assert_script_run("zypper -n -q patch");

    script_run('exit');
}

sub test_flags() {
    return { 'milestone' => 1, 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
