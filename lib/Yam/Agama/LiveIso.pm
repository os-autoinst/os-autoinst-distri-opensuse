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
use v5.20;
use feature qw(signatures);
no warnings qw(experimental::signatures);
use testapi;
use Mojo::JSON qw(decode_json);
use File::Temp qw(tempfile);

our @EXPORT = qw(read_live_iso);

# Extract a member from the ISO via isoinfo. Args are passed as a LIST, so no
# shell is spawned and the ISO value can never be parsed as shell syntax
# (command injection fix, poo#202788). Dies with $errmsg on isoinfo failure.
sub _isoinfo_extract ($member, $errmsg) {
    open(my $fh, '-|', 'isoinfo', '-j', 'UTF-8', '-R', '-x', $member,
        '-i', get_var('ISO')) or die "Cannot run isoinfo: $!";
    binmode $fh;
    my $data = do { local $/; <$fh> };
    close $fh;
    die $errmsg if $? != 0;
    return $data;
}

sub read_iso_info () {
    return _isoinfo_extract('/LiveOS/.info', 'Error getting info from ISO image');
}

# /LiveOS/.packages.json.gz is a gzipped JSON array of {name, version, ...}.
# Decompressed via the gunzip binary over a temp file (no shell pipe,
# deadlock-free), then decoded into an arrayref.
sub _read_packages_json () {
    my $gz = _isoinfo_extract('/LiveOS/.packages.json.gz',
        'Error getting Agama packages info from ISO image');

    my ($tfh, $tpath) = tempfile(SUFFIX => '.json.gz', UNLINK => 1);
    binmode $tfh;
    print {$tfh} $gz;
    close $tfh;

    open(my $fh, '-|', 'gunzip', '-c', $tpath) or die "Cannot run gunzip: $!";
    my $json = do { local $/; <$fh> };
    close $fh;
    die 'Error decompressing Agama packages info' if $? != 0;

    return decode_json($json);
}

sub parse_agama_packages () {
    my %env_var = (
        AGAMA_PACKAGE_VERSION => 'agama',
        AGAMA_AUTOINSTALL_PACKAGE_VERSION => 'agama-autoinstall',
        AGAMA_CLI_PACKAGE_VERSION => 'agama-cli',
        AGAMA_WEBUI_PACKAGE_VERSION => 'agama-web-ui',
    );
    my %version = map { $_->{name} => $_->{version} } @{_read_packages_json()};

    set_var($_, $version{$env_var{$_}} || '17+0') for keys %env_var;
    join "\n", map { "$_ => " . ($version{$_} || '17+0') } sort values %env_var;
}

sub record_agama_info ($info, $pkgs, $major_version) {
    record_info('AGAMA INFO',
        "ENV vars:\n" .
          "AGAMA_VERSION=$major_version\n\n" .
          "ISO info:\n$info\n" .
          "Version of packages:\n$pkgs");
}

sub read_live_iso () {
    return unless get_var('ISO');
    my $info = read_iso_info();
    my $pkgs = parse_agama_packages();
    $info =~ /^Image.version:\s+(?<major_version>\d+\.\w+)\./m;
    # Agama version was not available yet on GM medium, so we inject the default value
    my $major = $+{major_version} // '17.0';
    set_var('AGAMA_VERSION', $major);
    record_agama_info($info, $pkgs, $major);
}

1;
