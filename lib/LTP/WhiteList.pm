# Copyright 2019-2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Override known failures for QAM
# Maintainer: Jan Baier <jbaier@suse.cz>

package LTP::WhiteList;

use base Exporter;
use strict;
use warnings;
use testapi;
use bmwqemu;
use bugzilla;
use Exporter;
use Mojo::UserAgent;
use Mojo::JSON;
use Mojo::File 'path';

our @EXPORT = qw(
  download_whitelist
  find_whitelist_testsuite
  find_whitelist_entry
  override_known_failures
  is_test_disabled
  list_skipped_tests
);

sub download_whitelist {
    my $path = get_var('LTP_KNOWN_ISSUES');
    return undef unless defined($path);

    my $res = Mojo::UserAgent->new->get($path)->result;
    unless ($res->is_success) {
        record_info("File not downloaded!", $res->message, result => 'softfail');
        set_var('LTP_KNOWN_ISSUES', undef);
        return;
    }
    my $basename = $path =~ s#.*/([^/]+)#$1#r;
    save_tmp_file($basename, $res->body);
    set_var('LTP_KNOWN_ISSUES', hashed_string($basename));
    mkdir('ulogs') if (!-d 'ulogs');
    bmwqemu::save_json_file($res->json, "ulogs/$basename");
}

sub find_whitelist_entry {
    my ($env, $suite, $test) = @_;

    $suite = find_whitelist_testsuite($suite);
    return undef unless ($suite);

    my @issues;
    if (ref($suite) eq 'ARRAY') {
        @issues = @{$suite};
    }
    else {
        $test =~ s/_postun$//g if check_var('KGRAFT', 1) && check_var('UNINSTALL_INCIDENT', 1);
        return undef unless exists $suite->{$test};
        @issues = @{$suite->{$test}};
    }

    foreach my $cond (@issues) {
        return $cond if (whitelist_entry_match($cond, $env));
    }

    return undef;
}

sub override_known_failures {
    my ($self, $env, $suite, $test) = @_;
    my $entry;

    if ($env->{retval} && ref($env->{retval}) eq 'ARRAY') {
        my %local_env = %$env;

        my @retvals = grep { $_ ne 0 } @{$env->{retval}};
        # if all retvals are zero, we might catch one of the `retval=>'^0$'` filters.
        @retvals = (0) unless (@retvals);

        for my $retval (@retvals) {
            my $tmp = find_whitelist_entry({%$env, retval => $retval}, $suite, $test);
            return 0 unless ($tmp);
            $entry //= $tmp;
        }
    } else {
        $entry = find_whitelist_entry($env, $suite, $test);
    }

    return 0 unless defined($entry);

    if (exists $entry->{bugzilla}) {
        my $info = bugzilla_buginfo($entry->{bugzilla});

        if (!defined($info) || !exists $info->{bug_status}) {
            $self->record_resultfile('Bugzilla error',
                "Failed to query bug #$entry->{bugzilla} status",
                result => 'fail');
            return;
        }

        my $status = lc $info->{bug_status};

        if ($status eq 'resolved' || $status eq 'verified') {
            $self->record_resultfile('Bug closed',
                "Bug #$entry->{bugzilla} is closed, ignoring whitelist entry",
                result => 'fail');
            return;
        }
    }

    my $msg = "Failure in LTP:$suite:$test is known, overriding to softfail";
    bmwqemu::diag($msg);
    $self->{result} = 'softfail';
    $self->record_soft_failure_result(join("\n", $msg, ($entry->{message} // ())));
    return 1;
}

sub is_test_disabled {
    my $entry = find_whitelist_entry(@_);

    return 1 if defined($entry) && exists $entry->{skip} && $entry->{skip};
    return 0;
}

sub find_whitelist_testsuite {
    my ($suite) = @_;

    my $path = get_var('LTP_KNOWN_ISSUES');
    return undef unless defined($path) and -e $path;

    my $content = path($path)->slurp;
    my $issues = Mojo::JSON::decode_json($content);
    return undef unless $issues;
    return $issues->{$suite};
}

sub list_skipped_tests {
    my ($env, $suite) = @_;
    my @skipped_tests;
    $suite = find_whitelist_testsuite($suite);
    return @skipped_tests unless ($suite);
    return @skipped_tests if (ref($suite) eq 'ARRAY');

    for my $test (keys(%$suite)) {
        my @entrys = grep { $_->{skip} && whitelist_entry_match($_, $env) } @{$suite->{$test}};
        push @skipped_tests, $test if @entrys;
    }
    return @skipped_tests;
}

sub whitelist_entry_match
{
    my ($entry, $env) = @_;
    my @attributes = qw(product ltp_version revision arch kernel backend retval flavor);

    foreach my $attr (@attributes) {
        next unless defined $entry->{$attr};
        return undef unless defined $env->{$attr};
        return undef if ($env->{$attr} !~ m/$entry->{$attr}/);
    }
    return $entry;
}

1;
