package opensusebasetest;
use base 'basetest';

use testapi;

# Base class for all openSUSE tests

sub clear_and_verify_console {
    my ($self) = @_;

    send_key "ctrl-l";
    assert_screen('cleared-console');

}

sub post_run_hook {
    my ($self) = @_;
    # overloaded in x11 and console
}

sub registering_scc {
    my ($self, $counter) = @_;

    send_key "alt-e";    # select email field
    type_string get_var("SCC_EMAIL");
    send_key "tab";
    type_string get_var("SCC_REGCODE");
    save_screenshot;
    send_key "alt-n", 1;
    my @tags = qw/local-registration-servers registration-online-repos import-untrusted-gpg-key module-selection/;
    push @tags, 'untrusted-ca-cert' if get_var('SCC_URL');
    while (check_screen(\@tags, 60 )) {
        if (match_has_tag("local-registration-servers")) {
            send_key "alt-o";
            @tags = grep { $_ ne 'local-registration-servers' } @tags;
            next;
        }
        elsif (match_has_tag("import-untrusted-gpg-key")) {
            if (check_var("IMPORT_UNTRUSTED_KEY", 1)) {
                send_key "alt-t", 1; # import
            }
            else {
                send_key "alt-c", 1; # cancel
            }
            next;
        }
        elsif (match_has_tag("registration-online-repos")) {
            send_key "alt-y", 1; # want updates
            @tags = grep { $_ ne 'registration-online-repos' } @tags;
            next;
        }
        elsif (get_var('SCC_URL') && match_has_tag("untrusted-ca-cert")) {
            # bsc#943966
            record_soft_failure if get_var('SCC_CERT');
            send_key "alt-t", 1; # trust
            @tags = grep { $_ ne 'untrusted-ca-cert' } @tags;
            next;
        }
        last;
    }

    assert_screen("module-selection");
    if (get_var('SCC_ADDONS')) {
        send_key 'tab'; # jump to beginning of addon selection
        for $a (split(/,/, get_var('SCC_ADDONS'))) {
            $counter = 30;
            while ($counter > 0) {
                if (check_screen("scc-help-selected", 5 )) {
                    send_key 'tab'; # end of addon fields, jump over control buttons
                    send_key 'tab';
                    send_key 'tab';
                    send_key 'tab';
                    send_key 'tab';
                }
                else {
                    send_key ' ';   # select checkbox for needle match
                    if (check_screen("scc-marked-$a", 5 )) {
                        last;   # match, go to next addon
                    }
                    else {
                        send_key ' ';   # unselect addon if it's not expected one
                        send_key 'tab'; # go to next field
                    }
                }
                $counter--;
            }
        }
        send_key 'alt-n';   # next, all addons selected
        for $a (split(/,/, get_var('SCC_ADDONS'))) {
            assert_screen("scc-addon-license-$a");
            send_key "alt-a";   # accept license
            send_key "alt-n";   # next
        }
        for $a (split(/,/, get_var('SCC_ADDONS'))) {
            $a = uc $a;     # change to uppercase to match variable
            if (my $regcode = get_var("SCC_REGCODE_$a")) {
                assert_screen("scc-addon-regcode-$a");
                send_key 'tab'; # jump to code field
                type_string ;
                send_key "alt-n";   # next
            }
        }
    }
    else {
        send_key "alt-n";   # next
    }
    sleep 10;   # scc registration need some time
}

sub export_logs {
    my $self = shift;

    send_key "ctrl-alt-f2";
    assert_screen("text-login", 10);
    type_string "root\n";
    sleep 2;
    type_password;
    type_string "\n";
    sleep 1;

    save_screenshot;

    type_string "cat /home/*/.xsession-errors* > /tmp/XSE\n";
    upload_logs "/tmp/XSE";
    save_screenshot;

    type_string "journalctl -b > /tmp/journal\n";
    upload_logs "/tmp/journal";
    save_screenshot;

    type_string "cat /var/log/X* > /tmp/Xlogs\n";
    upload_logs "/tmp/Xlogs";
    save_screenshot;
}

sub export_captured_audio {
    my $self = shift;

    upload_logs ref($self)."-captured.wav";
}

sub bootmenu_down_to($) {
    my ($self, $tag) = @_;

    return if check_screen $tag, 2;

    for ( 1 .. 10 ) {
        my $ret = wait_screen_change {
            send_key 'down';
        };
        last unless $ret;
        return if check_screen $tag, 2;
    }
    # fail
    assert_screen $tag, 3;
}

1;
# vim: set sw=4 et:
