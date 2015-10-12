use base "installbasetest";
use strict;
use testapi;
use utils;
use ttylogin;

sub run() {

    wait_boot;

    if (get_var('ZDUP_IN_X')) {
        x11_start_program('xterm');
        become_root;
    }
    else {
        # Remove the graphical stuff
        # This do not work in 13.2
        # script_sudo "/sbin/init 3";

        ttylogin('4', 'root');

        # Remove the --force when this is fixed:
        # https://bugzilla.redhat.com/show_bug.cgi?id=1075131
        if ( check_var( 'HDDVERSION', "SLES-11" ) ) { #set default runlevel 3 for sle11
            type_string "sed -i 's/id:5:initdefault:/id:3:initdefault:/g' /etc/inittab\n";
        }
        else {
            script_run("systemctl set-default --force multi-user.target");
        }
        # The CD was ejected in the bootloader test
        script_run("/sbin/reboot");

        wait_boot textmode => 1;

        ttylogin('4', 'root');
    }

    script_run "PS1=\$";    # set constant shell promt

    # Disable console screensaver
    assert_script_run("setterm -blank 0");

    # bnc#949188. kernel panic on 13.2
    if (get_var('HDD_1', '') =~ /opensuse-13\.2/) {
        record_soft_failure;
        assert_script_run("zypper -n rm apparmor-abstractions");
    }
}

1;
# vim: set sw=4 et:
