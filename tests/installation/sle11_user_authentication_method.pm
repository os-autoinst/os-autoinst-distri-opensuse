use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;

    my $ret = assert_screen 'user-authentification-method', 40;
    if ($ret->{needle}->has_tag('ldap-selected')) {
       send_key 'alt-o';
       assert_screen 'local-user-selected';
    }
    send_key $cmd{next};
}

1;
