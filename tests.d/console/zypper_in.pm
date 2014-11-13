use base "consolestep";
use bmwqemu;

sub run() {
    my $self = shift;
    become_root();
    type_string "PS1=\"# \"\n";

    script_run("killall gpk-update-icon kpackagekitsmarticon packagekitd");

    #script_run("zypper ar http://download.opensuse.org/repositories/Cloud:/EC2/openSUSE_Factory/Cloud:EC2.repo"); # for suse-ami-tools
    my $pkgname = "sysstat";
    script_run("zypper -n in screen rsync $pkgname; echo zypper-in-status-\$? > /dev/$serialdev");
    wait_serial( "zypper-in-status-0", 60 ) || die "zypper failed";

    send_key "ctrl-l";    # clear screen to see that second update does not do any more
    script_run("rpm -e $pkgname");
    script_run("rpm -q $pkgname");
    script_run('exit');
    assert_screen( "package-$pkgname-not-installed", 5 );
}

1;
# vim: set sw=4 et:
