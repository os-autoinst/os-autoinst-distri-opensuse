package isotovideo;
use strict;
use utf8;
use warnings;

sub VERSION {
    my ($package, $version) = @_;

    die "isotovideo interface version $version required--this is version $main::INTERFACE" if $version != $main::INTERFACE;
}

sub get_version {
    my $version = $main::INTERFACE;
    ($version) =~ /\d+/;
    return $version;
}

1;

__END__
