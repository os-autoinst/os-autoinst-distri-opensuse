package opensusebasetest;
use base 'basetest';

use testapi;

# Base class for all openSUSE tests

sub clear_and_verify_console {
    my ($self) = @_;

    send_key "ctrl-l";
    assert_screen('cleared-console');

}

sub pass_disk_encrypt_check {
    my ($self) = @_;

    assert_screen("encrypted-disk-password-prompt", 200);
    type_password;    # enter PW at boot
    send_key "ret";
}

sub post_run_hook {
    my ($self) = @_;
    # overloaded in x11 and console
}

sub registering_scc {
    my ($self) = @_;

    send_key "alt-e";    # select email field
    type_string get_var("SCC_EMAIL");
    send_key "tab";
    type_string get_var("SCC_REGCODE");
    send_key "alt-n", 1;
    my @tags = qw/local-registration-servers registration-online-repos import-untrusted-gpg-key/;
    while ( my $ret = check_screen(\@tags, 60 )) {
        if ($ret->{needle}->has_tag("local-registration-servers")) {
            send_key "alt-o";
            @tags = grep { $_ ne 'local-registration-servers' } @tags;
            next;
        }
        elsif ($ret->{needle}->has_tag("import-untrusted-gpg-key")) {
            if (check_var("IMPORT_UNTRUSTED_KEY", 1)) {
                send_key "alt-t", 1; # import
            }
            else {
                send_key "alt-c", 1; # cancel
            }
            next;
        }
        elsif ($ret->{needle}->has_tag("registration-online-repos")) {
            send_key "alt-y", 1; # want updates
            @tags = grep { $_ ne 'registration-online-repos' } @tags;
            next;
        }
        last;
    }

    assert_screen("module-selection");
    send_key "alt-n", 1;
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

    if ( check_var("DESKTOP", "kde") ) {
        if ( get_var('PLASMA5') ) {
            my $fn = '/tmp/plasma5_configs.tar.bz2';
            my $cmd = sprintf 'tar cjf %s /home/%s/.config/*rc', $fn, $username;
            type_string "$cmd\n";
            upload_logs $fn;
        }
        else {
            my $fn = '/tmp/kde4_configs.tar.bz2';
            my $cmd = sprintf 'tar cjf %s /home/%s/.kde4/share/config/*rc', $fn, $username;
            type_string "$cmd\n";
            upload_logs $fn;
        }
        save_screenshot;
    }

    type_string "if [ -f /etc/OPENQA_ASSET_TAG ] ; then cat /etc/OPENQA_ASSET_TAG; fi\n";
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

sub key_round($$;$) {
    my ($self, $tag, $key, $counter, $timeout) = @_;

    $counter //= 20;
    $timeout //= 1;
    while ( !check_screen( $tag, $timeout ) ) {
        send_key $key;
        if (!$counter--) {
            # DIE!
            assert_screen $tag, 1;
        }
    }
}

1;
# vim: set sw=4 et:
