use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self   = shift;
    my $iso    = get_var("ISO") || get_var('HDD_1');
    my $size   = $iso?-s $iso:0;
    my $result = 'ok';
    my $max    = get_var("ISO_MAXSIZE", 0);
    if (!$size || !$max || $size > $max ) {
        $result = 'fail';
    }
    bmwqemu::diag("check if actual iso size $size fits $max: $result");
    $self->result($result);
}

sub test_flags() {
    return { important => 1 };
}

1;
# vim: set sw=4 et:
