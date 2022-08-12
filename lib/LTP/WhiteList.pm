# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Override known failures for QAM
# Maintainer: Jan Baier <jbaier@suse.cz>

package LTP::WhiteList;

use strict;
use warnings;
use testapi;
use bmwqemu;
use bugzilla;
use Encode;
use Exporter;
use File::Copy 'copy';
use Mojo::UserAgent;
use Mojo::File 'path';
use YAML::PP;

sub new {
    my $class = shift;
    my $self = bless({}, $class);
    my $path = get_var('LTP_KNOWN_ISSUES_LOCAL');

    if (!defined($path) && get_var('LTP_KNOWN_ISSUES')) {
        $path = _download_whitelist();
    }

    $self->{whitelist} = _load_whitelist_file($path) if $path;
    $self->{whitelist} ||= {};
    return $self;
}

sub _download_whitelist {
    my $path = get_var('LTP_KNOWN_ISSUES');
    return undef unless defined($path);

    my $res = Mojo::UserAgent->new(max_redirects => 5)->get($path)->result;
    unless ($res->is_success) {
        record_info("File not downloaded!", $res->message, result => 'softfail');
        set_var('LTP_KNOWN_ISSUES_LOCAL', '');
        return;
    }

    my $basename = $path =~ s#.*/([^/]+)#$1#r;
    my $lfile = hashed_string($basename);

    mkdir('ulogs') if (!-d 'ulogs');
    save_tmp_file($basename, $res->body);
    copy($lfile, "ulogs/$basename");

    set_var('LTP_KNOWN_ISSUES_LOCAL', $lfile);
    return $lfile;
}

sub find_whitelist_entry {
    my ($self, $env, $suite, $test) = @_;

    $suite = $self->{whitelist}->{$suite};
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
        return $cond if (_whitelist_entry_match($cond, $env));
    }

    return undef;
}

sub override_known_failures {
    my ($self, $testmod, $env, $suite, $testname) = @_;
    my $entry;

    if ($env->{retval} && ref($env->{retval}) eq 'ARRAY') {
        my %local_env = %$env;

        my @retvals = grep { $_ ne 0 } @{$env->{retval}};
        # if all retvals are zero, we might catch one of the `retval=>'^0$'` filters.
        @retvals = (0) unless (@retvals);

        for my $retval (@retvals) {
            my $tmp = $self->find_whitelist_entry({%$env, retval => $retval}, $suite, $testname);
            return 0 unless ($tmp);
            $entry //= $tmp;
        }
    } else {
        $entry = $self->find_whitelist_entry($env, $suite, $testname);
    }

    return 0 unless defined($entry);

    if (exists $entry->{bugzilla}) {
        my $info = bugzilla_buginfo($entry->{bugzilla});

        if (!defined($info) || !exists $info->{bug_status}) {
            $testmod->record_resultfile('Bugzilla error',
                "Failed to query bug #$entry->{bugzilla} status",
                result => 'fail');
            return;
        }

        my $status = lc $info->{bug_status};

        if ($status eq 'resolved' || $status eq 'verified') {
            $testmod->record_resultfile('Bug closed',
                "Bug #$entry->{bugzilla} is closed, ignoring whitelist entry",
                result => 'fail');
            return;
        }
    }

    my $msg = "Failure in LTP:$suite:$testname is known, overriding to softfail";
    bmwqemu::diag($msg);
    $testmod->{result} = 'softfail';
    $testmod->record_soft_failure_result(join("\n", $msg, ($entry->{message} // ())));
    return 1;
}

sub is_test_disabled {
    my $self = shift;
    my $entry = $self->find_whitelist_entry(@_);

    return 1 if defined($entry) && exists $entry->{skip} && $entry->{skip};
    return 0;
}

sub _load_whitelist_file {
    my $path = shift;
    return undef unless defined($path) and -e $path;

    # YAML::PP can handle both JSON and YAML
    # NOTE: JSON Surrogate Pairs not supported
    my $yp = YAML::PP->new(schema => [qw/ + Merge /]);

    my $content = decode_utf8(path($path)->slurp);

    # YAML::PP cannot handle BOM => remove it
    $content =~ s/^\x{FEFF}//;
    return $yp->load_string($content);
}

sub list_skipped_tests {
    my ($self, $env, $suite) = @_;
    my @skipped_tests;

    $suite = $self->{whitelist}->{$suite};
    return @skipped_tests unless ($suite);
    return @skipped_tests if (ref($suite) eq 'ARRAY');

    for my $test (keys(%$suite)) {
        my @entrys = grep { $_->{skip} && _whitelist_entry_match($_, $env) } @{$suite->{$test}};
        push @skipped_tests, $test if @entrys;
    }
    return @skipped_tests;
}

sub _whitelist_entry_match
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
