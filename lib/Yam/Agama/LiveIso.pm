## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Live ISO class to retrieve ISO data
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Yam::Agama::LiveIso;

use base Exporter;
use Exporter;
use base 'opensusebasetest';
use strict;
use warnings;
use testapi;

our @EXPORT = qw(read_live_iso);

# In product development, the staging jobs don't have ISO variable set, they use ISO_1 instead
my $iso_path = get_var('ISO', get_var('ISO_1'));

sub read_iso_info {
    my $iso_info = `isoinfo -j UTF-8 -R -x /LiveOS/.info -i $iso_path`;
    die "Error getting info from ISO image" if ($? != 0);
    return $iso_info;
}

sub get_package_version {
    my ($package_name) = @_;
    my $command = "isoinfo -j UTF-8 -R -x /LiveOS/.packages.json.gz -i $iso_path" .
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

    # Set each package version as environment variable
    set_var('AGAMA_PACKAGE_VERSION', $versions{'agama'} || '17+0');
    set_var('AGAMA_AUTOINSTALL_PACKAGE_VERSION', $versions{'agama-autoinstall'} || '17+0');
    set_var('AGAMA_CLI_PACKAGE_VERSION', $versions{'agama-cli'} || '17+0');
    set_var('AGAMA_WEBUI_PACKAGE_VERSION', $versions{'agama-web-ui'} || '17+0');
    join("\n", map { $_ . " => " . ($versions{$_} || '17+0') } keys %versions);
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
    return unless $iso_path;
    my $info = read_iso_info();
    my $pkgs = parse_agama_packages();
    $info =~ /^Image.version:\s+(?<major_version>\d+\.\w+)\./m;
    # Agama version was not available yet on GM medium, so we inject the default value
    set_var("AGAMA_VERSION", $+{'major_version'} // '17.0');
    record_agama_info($info, $pkgs, ($+{'major_version'} || '17.0'));
}

1;
