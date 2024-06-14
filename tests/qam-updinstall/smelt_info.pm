use strict;
use warnings;
use base "opensusebasetest";
use testapi;

use serial_terminal 'select_serial_terminal';
use maintenance_smelt qw(get_packagebins_in_modules get_incident_packages);
use version_utils 'is_sle';

sub run {
    my ($self, $run_args) = @_;

    my $incident_id = get_required_var('INCIDENT_ID');
    my $repos = get_required_var('INCIDENT_REPO');

    my @modules = split(/,/, $repos);
    foreach (@modules) {
        # substitue SLES_SAP for LTSS repo at this point is SAP ESPOS
        $_ =~ s/SAP_(\d+(-SP\d)?)/$1-LTSS/ if is_sle('15+');
        next if s{http.*SUSE_Updates_(.*)/?}{$1};
        die 'Modules regex failed. Modules could not be extracted from repos variable.';
    }

    # Get packages affected by the incident.
    my @packages = get_incident_packages($incident_id);
    $run_args->{packages} = \@packages;

    # Get binaries that are in each package across the modules that are in the repos.
    my %bins;
    foreach (@packages) {
        %bins = (%bins, get_packagebins_in_modules({package_name => $_, modules => \@modules}));
        # hash of hashes with keys 'name', 'supportstatus' and 'package'.
        # e.g. https://smelt.suse.de/api/v1/basic/maintained/grub2
    }
    die "Parsing binaries from SMELT data failed" if not keys %bins;
    $run_args->{bins} = \%bins;

    my @l2 = grep { ($bins{$_}->{supportstatus} eq 'l2') } keys %bins;
    my @l3 = grep { ($bins{$_}->{supportstatus} eq 'l3') } keys %bins;
    my @unsupported = grep { ($bins{$_}->{supportstatus} eq 'unsupported') } keys %bins;

    $run_args->{l2} = \@l2;
    $run_args->{l3} = \@l3;
    $run_args->{unsupported} = \@unsupported;
}

1;
