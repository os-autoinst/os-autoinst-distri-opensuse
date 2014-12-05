package opensusebasetest;
use base 'basetest';

use testapi qw(send_key assert_screen type_password);

# Base class for all openSUSE tests

sub clear_and_verify_console {
    my ($self) = @_;

    send_key "ctrl-l";
    assert_screen('cleared-console');

}

sub pass_disk_encrypt_check {
    my ($self) = @_;

    assert_screen("encrypted-disk-password-prompt");
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

1;
# vim: set sw=4 et:
