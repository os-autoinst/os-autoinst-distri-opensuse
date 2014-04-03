use base "basetest";
use bmwqemu;

sub is_applicable() {
    my $self = shift;

    # in live we don't have a password for root so ssh doesn't
    # work anyways, and except staging_core image, the rest of
    # staging_* images don't need run this test case
    return !$ENV{LIVETEST} && !( $ENV{FLAVOR} =~ /staging_[a-z]/ );
}

sub run() {
    my $self = shift;
    become_root();
    script_run("killall gpk-update-icon kpackagekitsmarticon packagekitd");
    script_run("zypper -n in sshfs");
    waitstillimage( 12, 90 );
    script_run('cd /var/tmp ; mkdir mnt ; sshfs localhost:/ mnt');
    waitforneedle( "accept-ssh-host-key", 3 );
    sendautotype("yes\n");    # trust ssh host key
    sendpassword;
    sendkey "ret";
    waitforneedle( 'sshfs-accepted', 3 );
    script_run('cd mnt/tmp');
    script_run("zypper -n in xdelta");
    script_run("rpm -e xdelta");
    script_run('cd /tmp');

    # we need to umount that otherwise root is considered logged in!
    script_run("umount /var/tmp/mnt");

    # become user again
    script_run('exit');
    $self->check_screen;
}

1;
