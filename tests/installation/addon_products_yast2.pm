use base "y2logsstep";
use strict;
use testapi;
use registration;

sub addon_yast2 {
    if (get_var("BETA_$b")) {
        assert_screen "addon-betawarning-$a";
        send_key "ret";
        assert_screen "addon-license-beta";
    }
    else {
        assert_screen "addon-license-$a";
    }
    send_key 'alt-a', 2;    # yes, agree
    send_key 'alt-n', 2;    # next
    assert_screen 'addon-yast2-patterns';
    sleep 2;
    send_key 'alt-v', 2;    # view tab
    send_key 'spc';         # open view menu
    send_key 'alt-r';
    send_key 'alt-r';       # go to repositories
    send_key 'ret';         # open repositories tab
    assert_screen "addon-yast2-repo-$a";
    send_key 'alt-a';       # accept
    assert_screen 'automatic-changes';
    send_key 'alt-o';       # OK
    if (check_screen 'unsupported-packages', 5) {
        record_soft_failure;
        send_key 'alt-o';
    }
    if (check_screen 'addon-installation-pop-up', 100) {    # e.g. RT reboot to activate new kernel
        send_key 'alt-o';                                   # OK
    }
    assert_screen "addon-installation-report";
    send_key 'alt-f';                                       # finish
    assert_screen 'scc-registration';

    if (get_var('SCC_REGISTER') eq 'addon') {
        fill_in_registration_data;
    }
    else {
        send_key "alt-s", 1;                                # skip SCC registration
        if (check_screen("scc-skip-reg-warning")) {
            send_key "alt-y", 1;                            # confirmed skip SCC registration
        }
        if (check_screen("scc-skip-base-system-reg-warning")) {
            send_key "alt-y", 1;                            # confirmed skip SCC registration
        }
        send_key "tab",                                 1;
        send_key "pgup",                                1;
        send_key_until_needlematch "addon-products-$a", 'down';
        if ((split(/,/, get_var('ADDONS')))[-1] ne $a) {
            send_key 'alt-a', 2;
        }
        else {
            send_key 'alt-o', 2;
        }
    }
}

sub run() {
    my $self = shift;
    x11_start_program("xdg-su -c '/sbin/yast2 add-on'");
    if ($password) { type_password; send_key "ret", 1; }
    if (check_screen 'packagekit-warning') {
        send_key 'alt-y';    # yes
    }
    assert_screen 'addon-products';
    send_key 'alt-a', 2;     # add add-on
    if (get_var("ADDONS")) {
        foreach $a (split(/,/, get_var('ADDONS'))) {
            our $b = uc $a;    # varibale name is upper case
            if (get_var("ADDONURL_$b")) {
                send_key 'alt-u';    # specify url
                send_key 'alt-n';
                assert_screen 'addonurl-entry', 3;
                type_string get_var("ADDONURL_$b");
                send_key 'alt-p';    # name
                type_string "SLE$b" . "12-SP1_repo";
                send_key 'alt-n';
                $self->addon_yast2;
            }
            else {
                send_key 'alt-v',                            3;             # DVD
                send_key 'alt-n',                            3;
                assert_screen 'dvd-selector',                3;
                send_key_until_needlematch 'addon-dvd-list', 'tab', 10;     # jump into addon list
                send_key_until_needlematch "addon-dvd-$a",   'down', 10;    # select addon in list
                send_key 'alt-o';                                           # continue
                $self->addon_yast2;
            }
        }
    }
    else {
        send_key 'alt-n', 2;                                                # done
    }
}

1;
# vim: set sw=4 et:
