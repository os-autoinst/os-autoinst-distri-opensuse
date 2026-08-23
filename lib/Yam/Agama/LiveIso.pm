## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Live ISO class to retrieve ISO data
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

=head1 Yam::Agama::LiveIso

C<Yam::Agama::LiveIso> - Retrieve Agama Live ISO metadata (image info and
package versions) and expose it through openQA variables.

=cut

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

=head2 _run_and_slurp

 _run_and_slurp($errmsg, @cmd);

Run C<@cmd> as a child process and return its slurped output. C<@cmd> is passed
as a LIST, so no shell is spawned and its arguments can never be parsed as shell
syntax (command injection fix, poo#202788). Dies with C<$errmsg> if the command
exits non-zero.

=cut

sub _run_and_slurp ($errmsg, @cmd) {
    open(my $fh, '-|', @cmd) or die "Cannot run $cmd[0]: $!";
    binmode $fh;
    my $data = do { local $/; <$fh> };
    close $fh;
    die $errmsg if $? != 0;
    return $data;
}

=head2 _write_tempfile

 _write_tempfile($content, $suffix);

Write binary C<$content> to a temporary file (auto-removed at exit) and return
its path. C<$suffix> defaults to C<.tmp>.

=cut

sub _write_tempfile ($content, $suffix = '.tmp') {
    my ($fh, $path) = tempfile(SUFFIX => $suffix, UNLINK => 1);
    binmode $fh;
    print {$fh} $content;
    close $fh;
    return $path;
}

=head2 _isoinfo_extract

 _isoinfo_extract($member, $errmsg);

Extract C<$member> from the ISO (C<get_var('ISO')>) via C<isoinfo> and return
its content. Dies with C<$errmsg> on failure. Returns an empty string, without
dying, if C<$member> is not present on the ISO (isoinfo exits 0 with no output
in that case).

=cut

sub _isoinfo_extract ($member, $errmsg) {
    return _run_and_slurp($errmsg,
        'isoinfo', '-j', 'UTF-8', '-R', '-x', $member, '-i', get_var('ISO'));
}

sub read_iso_info () {
    return _isoinfo_extract('/LiveOS/.info', 'Error getting info from ISO image');
}

=head2 _read_packages_json

 _read_packages_json();

Read C</LiveOS/.packages.json.gz> (a gzipped JSON array of C<{name, version,
...}>) from the ISO, decompress it via the C<gunzip> binary over a temp file (no
shell pipe, deadlock-free) and return the decoded arrayref. Some media (e.g. the
Online medium) don't ship this file at all; isoinfo then returns empty output
rather than failing, so that case is treated as "no package info available"
instead of a decompression error.

=cut

sub _read_packages_json () {
    my $gz = _isoinfo_extract('/LiveOS/.packages.json.gz',
        'Error getting Agama packages info from ISO image');
    return [] unless length $gz;
    my $tpath = _write_tempfile($gz, '.json.gz');
    my $json = _run_and_slurp('Error decompressing Agama packages info',
        'gunzip', '-c', $tpath);
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
