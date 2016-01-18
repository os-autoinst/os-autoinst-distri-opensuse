use base "consoletest";
use testapi;

sub run() {
    my $self = shift;
    become_root();
    assert_script_run("zypper -n in awesome");
    script_run("echo -e '#!/bin/sh\\n\\nexec dbus-launch --exit-with-session awesome' > /home/$username/.xinitrc");
    script_run("cat /home/$username/.xinitrc");
    script_run("exit");
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
