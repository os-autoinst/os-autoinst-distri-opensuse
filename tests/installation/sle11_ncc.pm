use base "y2logsstep";
use strict;
use testapi;

sub ncc_continue_actions() {
    # untrusted gnupg keys may appear
    while ( my $ret = check_screen( [qw/ncc-import-key ncc-configuration-done/], 120 )) {
        last if $ret->{needle}->has_tag('ncc-configuration-done');
        send_key "alt-i";   
    }
}

sub run(){
    my $self=shift;

    assert_screen 'novell-customer-center', 30;

    send_key $cmd{'next'};
    assert_screen 'ncc-manual-interaction', 60; # contacting server take time
    send_key 'alt-o';
    assert_screen 'ncc-security-warning', 30;
    send_key 'ret';

    my $emailaddr = get_var("NCC_EMAIL");
    my $ncc_code = get_var("NCC_CODE");

    assert_screen 'ncc-input-emailaddress', 20;
    type_string $emailaddr;
    $self->key_round('ncc-confirm-emailaddress', 'tab');
    type_string $emailaddr;
    $self->key_round('ncc-input-activationcode', 'tab');
    type_string $ncc_code;
    
    if (get_var("ADDONS")) {
        foreach $a (split(/,/, get_var("ADDONS"))) {
            next if ($a =~ /sdk/);
            if ($a eq 'ha') {
                my $hacode = get_var("NCC_HA_CODE");
                $self->key_round('ncc-input-hacode', 'tab');
                type_string $hacode;
            }
            if ($a eq 'geo') {
                my $geocode = get_var("NCC_GEO_CODE");
                $self->key_round('ncc-input-geocode', 'tab');
                type_string $geocode;
            }
        }
    }

    $self->key_round('ncc-submit', 'tab');
    send_key 'ret';

    $self->key_round('ncc-continue-process', 'tab');
    send_key 'ret';

    ncc_continue_actions();
    send_key 'alt-o'; # done 
}

1;
