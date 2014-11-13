#!/usr/bin/perl -w
use strict;
use base "installstep";

use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$vars{LIVECD}  && !$vars{AUTOYAST};
}

sub run() {
    my $self = shift;
    assert_screen( "scc-registration", 30 );
    if ($vars{SCC_EMAIL} && $vars{SCC_REGCODE} && (!$vars{SCC_REGISTER} || $vars{SCC_REGISTER} eq 'installation')) {

        send_key "alt-e";    # select email field
        type_string $vars{SCC_EMAIL};
        send_key "tab";
        type_string $vars{SCC_REGCODE};
        send_key $cmd{"next"}, 1;
        my @tags = qw/local-registration-servers registration-online-repos import-untrusted-gpg-key/;
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

        assert_screen("registration-online-repos", 1);
        send_key "alt-y", 1;    # want updates

        assert_screen("module-selection", 10);
        send_key $cmd{"next"}, 1;
    }
    else {
        send_key "alt-s", 1;     # skip SCC registration
        if ( check_screen( "scc-skip-reg-warning", 10 ) ) {
            send_key "alt-y", 1;    # confirmed skip SCC registration
        }
    }
    return 0;
}

1;

# vim: set sw=4 et:
