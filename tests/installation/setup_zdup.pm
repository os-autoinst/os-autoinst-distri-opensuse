use base "installbasetest";
use strict;
use testapi;

sub run() {
    # wait booted
    if (get_var("NOAUTOLOGIN")) {
        assert_screen 'displaymanager', 200;
    }
    else {
        assert_screen 'generic-desktop', 200;
    }

    # log into text console
    send_key "ctrl-alt-f4";
    assert_screen "linux-login", 15;
    type_string "root\n";
    assert_screen 'password-prompt';
    type_password;
    type_string "\n";
    sleep 3;

    # Remove the graphical stuff
    # This do not work in 13.2
    # script_sudo "/sbin/init 3";

    # Remove the --force when this is fixed:
    # https://bugzilla.redhat.com/show_bug.cgi?id=1075131
    if ( check_var( 'HDDVERSION', "SLES-11-sp3" ) ) { #set default runlevel 3 for sle11
        type_string "sed -i 's/id:5:initdefault:/id:3:initdefault:/g' /etc/inittab\n";
    }
    else {
        script_run("systemctl set-default --force multi-user.target");
    }
    # The CD was ejected in the bootloader test
    script_run("/sbin/reboot");

    # login, again : )
    assert_screen "grub2", 300; # boot menu appears
    send_key "ret";
    if ( check_var( 'HDDVERSION', "SLES-11-sp3" ) ) {
        check_screen 'linux-login';
        send_key "ctrl-alt-f4"; #switch to another tty, black background
    }
    assert_screen "linux-login", 30; # login prompt appears
    type_string "root\n";
    assert_screen 'password-prompt';
    type_password;
    type_string "\n";
    sleep 3;

    # Reloging
    # assert_screen "linux-login", 3;
    # type_string "$username\n";
    # sleep 2;
    # type_password;
    # type_string "\n";
    # sleep 3;

    type_string "PS1=\$\n";    # set constant shell promt
    sleep 1;

    # Disable console screensaver
    script_run("setterm -blank 0");
}

1;
# vim: set sw=4 et:
