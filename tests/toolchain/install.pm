use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    if (!check_var('ARCH', 's390x')) {
        send_key 'ctrl-alt-f4';
        assert_screen 'tty4-selected';
        assert_screen 'text-login';
        type_string "root\n";
        assert_screen 'password-prompt', 10;
        type_password;
        send_key 'ret';
    }
    assert_screen 'text-logged-in';
    # disable packagekitd
    script_run 'systemctl mask packagekit.service';
    script_run 'systemctl stop packagekit.service';
    # scc registration is mandatory
    script_run 'zypper lr -d';
    assert_screen 'pool-and-update-channel';
    # toolchain channels
    if (!check_var('ADDONS', 'tcm')) {
        my $arch = get_var('ARCH');
        assert_script_run "zypper ar -f http://download.suse.de/ibs/SUSE/Products/SLE-Module-Toolchain/12/$arch/product/ SLE-Module-Toolchain12-Pool";
        assert_script_run "zypper ar -f http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Toolchain/12/$arch/update/ SLE-Module-Toolchain12-Updates";
    }
    assert_script_run 'zypper -n in -t pattern gcc5';
    assert_script_run 'zypper -n up';
    # reboot when runing processes use deleted files after packages update
    type_string "zypper ps|grep 'PPID' || echo OK | tee /dev/$serialdev\n";
    if (!wait_serial("OK", 100)) {
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
