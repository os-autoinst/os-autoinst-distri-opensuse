package isotovideo;
use strict;
use utf8;
use warnings;

sub VERSION {
    my ($package, $version) = @_;
    my $v = $main::INTERFACE // $OpenQA::Isotovideo::Interface::version;

    die "isotovideo interface version $version required--this is version $v" if $version != $v;
}

sub get_version {
    my $version = $main::INTERFACE // $OpenQA::Isotovideo::Interface::version;
    return unless defined $version;
    ($version) =~ /\d+/;
    return $version;
}

1;

__END__
