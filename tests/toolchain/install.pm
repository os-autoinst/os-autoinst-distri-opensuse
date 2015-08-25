use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    send_key 'ctrl-alt-f4';
    assert_screen 'tty4-selected';
    assert_screen 'text-login';
    type_string "root\n";
    assert_screen 'password-prompt', 10;
    type_password;
    send_key 'ret';
    assert_screen 'text-logged-in';
    # disable packagekitd
    script_run 'systemctl mask packagekit.service';
    script_run 'systemctl stop packagekit.service';
    # add SLES libraries for toolchain repo
    assert_script_run 'zypper ar http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Toolchain/12/x86_64/update/ SLE-Module-Toolchain';
    assert_script_run 'zypper ar http://download.suse.de/ibs/SUSE/Updates/SLE-SERVER/12/x86_64/update/ SLE-SERVER';
    assert_script_run 'zypper -n in gcc5 gcc5-c++ binutils gdb';
    assert_script_run 'zypper -n up';
    # reboot when runing processes use deleted files after packages update
    type_string "zypper ps|grep 'PID' && echo reboot|tee /dev/$serialdev\n";
    if (wait_serial("reboot", 100)) {
        type_string "shutdown -r now\n";
        assert_screen 'displaymanager', 150;
        send_key 'ctrl-alt-f4';
        assert_screen 'tty4-selected';
        assert_screen 'text-login';
        type_string "root\n";
        assert_screen 'password-prompt', 10;
        type_password;
        send_key 'ret';
    }
}

sub test_flags() {
    return { 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
