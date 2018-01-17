package isotovideo_interface;
use strict;
use utf8;
use warnings;

sub VERSION {
    my ($package, $version) = @_;

    die "isotovideo interface version $version required--this is version $main::INTERFACE" if $version != $main::INTERFACE;
}

1;

__END__
