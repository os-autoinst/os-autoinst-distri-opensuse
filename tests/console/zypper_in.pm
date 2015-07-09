use base "consoletest";
use testapi;

sub run() {
    my $self = shift;
    become_root();

    script_run("zypper lr -d | tee /dev/$serialdev");

    my $pkgname = get_var("PACKAGETOINSTALL");
    assert_script_run("zypper -n in screen $pkgname");
    send_key "ctrl-l";    # clear screen to see that second update does not do any more
    assert_script_run("rpm -e $pkgname");
    script_run("rpm -q $pkgname");
    script_run('exit');
    assert_screen "package-$pkgname-not-installed", 5;
}

1;
# vim: set sw=4 et:
