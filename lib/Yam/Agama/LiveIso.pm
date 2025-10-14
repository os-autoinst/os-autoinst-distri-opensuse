## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Live ISO class to retrieve ISO data
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::LiveIso;

use base Exporter;
use Exporter;
use base 'opensusebasetest';
use strict;
use warnings;
use testapi;

our @EXPORT = qw(read_live_iso);

sub read_iso_info {
    my $iso_info = `isoinfo -j UTF-8 -R -x /LiveOS/.info -i @{[ get_var('ISO') ]}`;
    die "Error getting info from ISO image" if ($? != 0);
    return $iso_info;
}

sub get_package_version {
    my ($package_name) = @_;
    my $command = "isoinfo -j UTF-8 -R -x /LiveOS/.packages.json.gz -i @{[ get_var('ISO') ]}" .
      " | gunzip" .
      " | jq -r '.[] | select(.name==\"$package_name\") | .version'";

    my $version = qx{$command};
    chomp($version);
    return $version;
}

sub parse_agama_packages {
    my @packages = qw(agama agama-autoinstall agama-cli agama-web-ui);
    my %versions = map { $_ => get_package_version($_) } @packages;
    die "Error getting Agama packages info from ISO image" if ($? != 0);
    join("\n", map { $_ . " => " . $versions{$_} } keys %versions);
}

sub record_agama_info {
    my ($info, $pkgs, $major_version) = @_;
    record_info('AGAMA INFO',
        "ENV vars:\n" .
          "AGAMA_VERSION=$major_version\n\n" .
          "ISO info:\n" .
          $info . "\n" .
          "Version of packages:\n" .
          $pkgs
    );
}

sub read_live_iso {
    my $info = read_iso_info();
    my $pkgs = parse_agama_packages();
    $info =~ /^Image.version:\s+(?<major_version>\d+\.\w+)\./m;
    set_var("AGAMA_VERSION", $+{'major_version'});
    record_agama_info($info, $pkgs, $+{'major_version'});
}

1;
