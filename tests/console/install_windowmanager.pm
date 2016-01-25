use base "consoletest";
use testapi;

sub run() {
    my $self = shift;
    become_root();
    if (check_var("DESKTOP", "awesome")) {
        assert_script_run("zypper -n in awesome");
        script_run("sed -i 's/^DEFAULT_WM.*\$/DEFAULT_WM=\"awesome\"/' /etc/sysconfig/windowmanager");
    }
    type_string "exit\n";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
