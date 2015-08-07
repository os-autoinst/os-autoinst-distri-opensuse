use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self   = shift;
    my $iso    = get_var("HDD_1");
    my $size   = -s $iso;
    my $result = 'ok';
    my $max    = get_var("ISO_MAXSIZE");
    if ( $size > $max ) {
        $result = 'fail';
    }
    bmwqemu::diag("check if actual hdd size $size fits $max: $result");
    $self->result($result);
}

sub test_flags() {
    return { 'important' => 1 };
}

1;
# vim: set sw=4 et:
