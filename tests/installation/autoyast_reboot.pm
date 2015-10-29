use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    if (get_var("AUTOUPGRADE")) {
        assert_screen("grub2", 5900);
    }
    else {
        assert_screen("grub2", 900);
    }
}

1;
