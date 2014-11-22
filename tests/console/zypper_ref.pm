use base "opensusebasetest";
use testapi;
use strict;

sub run {
    become_root();
    type_string "PS1=\"# \"\n";

    type_string "zypper lr\n";
    save_screenshot;

    if (get_var('SCC_EMAIL') && get_var('SCC_REGCODE') && (get_var('SCC_REGISTER', 'console') eq 'console')) {
        type_string "yast scc; echo yast-scc-done-\$? > /dev/$serialdev\n";

        assert_screen( "scc-registration", 30 );

        send_key "alt-e";    # select email field
        type_string $vars{SCC_EMAIL};
        send_key "tab";
        type_string $vars{SCC_REGCODE};
        send_key $cmd{"next"}, 1;
        my @tags = qw/local-registration-servers registration-online-repos module-selection/;
        while ( my $ret = check_screen(\@tags, 60 )) {
            if ($ret->{needle}->has_tag("local-registration-servers")) {
                send_key $cmd{ok};
                shift @tags;
                next;
            }
            elsif ($ret->{needle}->has_tag("import-untrusted-gpg-key")) {
                send_key "alt-c", 1;
                next;
            }
            last;
        }

        assert_screen("module-selection", 10);
        send_key $cmd{"next"}, 1;

        wait_serial("yast-scc-done-0") || die "yast scc failed";

        type_string "zypper lr\n";
        assert_screen "scc-repos-listed";
    }

    script_run("zypper ref; echo zypper-ref-\$? > /dev/$serialdev");
    # don't trust graphic driver repo
    if ( check_screen("new-repo-need-key", 20) ) {
        type_string "r\n";
    }
    wait_serial("zypper-ref-0") || die "zypper failed";
    assert_screen("zypper_ref");
    type_string "exit\n";
}

1;

# vim: set sw=4 et:
