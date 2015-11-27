use base "installbasetest";
use strict;
use testapi;
use utils;

sub run() {
    send_key "ctrl-l", 1;

    # Print zypper repos
    script_run("zypper lr -d");
    # Remove the --force when this is fixed:
    # https://bugzilla.redhat.com/show_bug.cgi?id=1075131
    if (check_var('HDDVERSION', "SLES-11-sp3")) {    #set back default runlevel 5 for sle11
        type_string "sed -i 's/id:3:initdefault:/id:5:initdefault:/g' /etc/inittab\n";
    }
    else {
        script_run("systemctl set-default --force graphical.target");
    }
    sleep 5;

    save_screenshot;

    # TODO: why not just script_run 'root' ?
    # switch to tty3 (in case we are in X)
    send_key "ctrl-alt-f3";
    assert_screen "text-login", 5;
    # Reboot after dup
    send_key "ctrl-alt-delete";

    wait_boot;
}

1;
# vim: set sw=4 et:
