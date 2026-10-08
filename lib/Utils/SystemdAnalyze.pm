# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parsers for systemd-analyze output
# Maintainer: QE-C team <qa-c@suse.de>

package Utils::SystemdAnalyze;
use base Exporter;
use strict;
use warnings;
use Mojo::Util 'trim';
use testapi 'record_info';

our @EXPORT = qw(extract_analyze_time extract_blame_time);

=head1 Utils::SystemdAnalyze

C<Utils::SystemdAnalyze> - Parsers for C<systemd-analyze> text output

=cut

# Convert a systemd time span (e.g. 821us, 6ms, 1.234s, 1min 2.345s,
# 1h 2min 3.456s) to seconds. Records a failed WARN and returns -1 if it
# can't be parsed.
sub _systemd_time_to_seconds
{
    my $str_time = trim(shift);

    if ($str_time !~ /^(?<check_hour>(?<hour>\d{1,2})\s*h\s*)?(?<check_min>(?<min>\d{1,2})\s*min\s*)?((?<sec>\d{1,2}\.\d{1,3})s|(?<ms>\d+)ms|(?<us>\d+)us)$/) {
        record_info("WARN", "Unable to parse systemd time '$str_time'", result => 'fail');
        return -1;
    }
    my $sec = $+{sec} // (defined($+{ms}) ? $+{ms} / 1000 : $+{us} / 1_000_000);
    $sec += $+{min} * 60 if (defined($+{check_min}));
    $sec += $+{hour} * 3600 if (defined($+{check_hour}));
    return $sec;
}

=head2 extract_analyze_time

    my $res = extract_analyze_time($output);

Parse C<systemd-analyze time> output and return a hashref with the C<kernel>,
C<initrd>, C<userspace> and C<overall> times in seconds. Lines not containing
C<Startup finished in> (e.g. an SSH login banner) are ignored. Returns undef if
any of those values is missing or can't be parsed.

=cut

sub extract_analyze_time {
    my $str_time = shift;
    my $res = {};
    # Pick the line that actually holds the timing, not blindly the first line:
    # ssh_script_output may prepend an SSH login banner / MOTD, which would
    # otherwise leave us parsing an empty or non-timing line (poo#203817).
    ($str_time) = grep { /Startup finished in/i } split(/\r?\n/, $str_time);
    return undef unless defined($str_time);
    $str_time =~ s/Startup finished in\s*//i;
    $str_time =~ s/=(.+)$/+$1 (overall)/;
    for my $time (split(/\s*\+\s*/, $str_time)) {
        $time = trim($time);
        my ($time, $type) = $time =~ /^(.+)\s*\((\w+)\)$/;
        $res->{$type} = _systemd_time_to_seconds($time);
        return undef if ($res->{$type} == -1);
    }
    foreach (qw(kernel initrd userspace overall)) { return undef unless exists($res->{$_}); }
    return $res;
}

=head2 extract_blame_time

    my $res = extract_blame_time($output);

Parse C<systemd-analyze blame> output and return a hashref mapping each unit
to its time in seconds. Lines that aren't C<< <time> <unit> >> entries, or whose
time can't be parsed, are skipped.

=cut

sub extract_blame_time {
    my $str_time = shift;
    my $ret = {};
    for my $line (split(/\r?\n/, $str_time)) {
        $line = trim($line);
        # Only <time> <service> lines are blame entries; skip anything else
        # (e.g. an SSH login banner / MOTD prepended to the output, poo#203817).
        # The time may span several tokens (e.g. "1min 30.000s"), each starting with a digit.
        my ($time, $service) = $line =~ /^((?:\d\S*\s+)*\d\S*)\s+(\S+)$/;
        next unless defined($service);
        my $sec = _systemd_time_to_seconds($time);
        next unless ($sec >= 0);
        $ret->{$service} = $sec;
    }
    return $ret;
}

1;
