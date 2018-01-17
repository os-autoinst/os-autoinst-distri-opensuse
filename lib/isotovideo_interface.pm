package isotovideo_interface;
use strict;
use utf8;
use warnings;

sub VERSION {
    my ($package, $version) = @_;

    qx/isotovideo --version/ =~ /interface v(\d+)/;
    my $last_version = $1 // 0;

    die "isotovideo interface version $version required--this is version $last_version" if $version != $last_version;
}

1;

__END__
