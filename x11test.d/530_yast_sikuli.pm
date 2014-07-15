use base "basetest";
use bmwqemu;

sub is_applicable() {
    return 0;    # disabled as sikuli does not install atm
    return $vars{DESKTOP} eq "kde" && !$vars{TUMBLEWEED} && !$vars{NICEVIDEO};
}

sub run() {
    my $self = shift;
    x11_start_program("xterm");

    #script_sudo("/sbin/OneClickInstallUI http://i.opensu.se/Documentation:Tools/sikuli");
    script_sudo("zypper ar http://download.opensuse.org/repositories/Documentation:/Tools/openSUSE_Factory/ doc");
    script_sudo("zypper ar http://download.opensuse.org/repositories/home:/bmwiedemann:/branches:/Documentation:/Tools/openSUSE_Factory/ bmwdoc");
    script_sudo("zypper -n --gpg-auto-import-keys in sikuli yast2-ycp-ui-bindings-devel ; echo sikuli installed > /dev/ttyS0");
    wait_serial "sikuli installed", 200;
    script_run("cd /tmp;curl openqa.opensuse.org/opensuse/qatests/ykuli.tar | tar x ; cd ykuli");
    assert_screen 'test-yast_sikuli-1', 3;
    script_run("./run_ykuli.sh ; echo yastsikuli finished > /dev/ttyS0");
    wait_serial "yastsikuli finished", 680;
    assert_screen 'test-yast_sikuli-2', 3;
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
