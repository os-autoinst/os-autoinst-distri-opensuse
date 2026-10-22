use strict;
use warnings;
use FindBin '$Bin';
use Test::More;
use Test::Exception;
use testapi qw(set_var);

do "$Bin/../tests/publiccloud/metadata.pm"
  or die $@ || $! || 'Failed to load tests/publiccloud/metadata.pm';

sub _metadata_package_for {
    my ($distri, $version, $provider) = @_;
    set_var('DISTRI', $distri);
    set_var('VERSION', $version);
    set_var('VERSION_TO_INSTALL', undef);
    set_var('PUBLIC_CLOUD', 1);
    set_var('PUBLIC_CLOUD_PROVIDER', $provider);
    return main::metadata_package();
}

my @cases = (
    ['sle', '15-SP7', 'AZURE', 'python3-azuremetadata', 'SLE 15 SP7 Azure uses python3 package'],
    ['sle', '16.0', 'EC2', 'python-ec2metadata', 'SLE 16 EC2 uses python package'],
    ['sle', '15-SP7', 'GCE', 'python-gcemetadata', 'SLE GCE uses python package'],
    ['sle', '15-SP7', 'OTHER', undef, 'SLE unsupported provider has no package'],
    ['sle-micro', '6.2', 'AZURE', 'python-azuremetadata', 'SL Micro 6.2 Azure uses python package'],
    ['sle-micro', '6.1', 'EC2', 'python3-ec2metadata', 'SL Micro 6.1 EC2 uses python3 package'],
    ['sle-micro', '6.0', 'GCE', 'python-gcemetadata', 'SL Micro 6.0 GCE uses python package'],
    ['sle-micro', '5.5', 'GCE', 'python3-gcemetadata', 'SL Micro 5.5 GCE uses python3 package'],
    ['sle-micro', '5.6', 'GCE', undef, 'SL Micro 5.6 GCE has no package mapping'],
);

my @fail_cases = (
    ['opensuse', '16.0', 'GCE', 'Unsupported OS for metadata package installation'],
);

for my $case (@cases) {
    my ($distri, $version, $provider, $expected, $description) = @$case;
    is(_metadata_package_for($distri, $version, $provider), $expected, $description);
}

for my $case (@fail_cases) {
    my ($distri, $version, $provider, $error) = @$case;
    throws_ok { _metadata_package_for($distri, $version, $provider) } qr/\Q$error\E/, $error;
}

set_var('DISTRI', undef);
set_var('VERSION', undef);
set_var('VERSION_TO_INSTALL', undef);
set_var('PUBLIC_CLOUD', undef);
set_var('PUBLIC_CLOUD_PROVIDER', undef);

done_testing;
