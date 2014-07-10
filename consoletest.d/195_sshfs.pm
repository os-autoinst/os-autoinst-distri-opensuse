use base "basetest";
use bmwqemu;

sub is_applicable() {
    my $self = shift;

    # in live we don't have a password for root so ssh doesn't
    # work anyways, and except staging_core image, the rest of
    # staging_* images don't need run this test case
    return !$vars{LIVETEST} && !( $vars{FLAVOR} =~ /^Staging2?[\-]DVD$/ );
}

sub run() {
    my $self = shift;
    become_root();
    script_run("killall gpk-update-icon kpackagekitsmarticon packagekitd");
    script_run("zypper -n in sshfs");
    waitstillimage( 12, 90 );
    script_run('cd /var/tmp ; mkdir mnt ; sshfs localhost:/ mnt');
    assert_screen "accept-ssh-host-key", 3;
    type_string "yes\n";    # trust ssh host key
    sendpassword;
    send_key "ret";
    assert_screen 'sshfs-accepted', 3;
    script_run('cd mnt/tmp');
    script_run("zypper -n in xdelta");
    script_run("rpm -e xdelta");
    script_run('cd /tmp');

    # we need to umount that otherwise root is considered logged in!
    script_run("umount /var/tmp/mnt");

    # become user again
    script_run('exit');
    assert_screen 'test-sshfs-1', 3;
}

1;
# vim: set sw=4 et:
