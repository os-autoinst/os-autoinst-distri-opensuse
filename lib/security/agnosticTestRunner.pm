#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: helper module for openQA-agnostic security tests
#
# Maintainer: QE Security <none@suse.de>

package security::agnosticTestRunner;

use strict;
use warnings;
use testapi qw(assert_script_run data_url parse_extra_log);
use registration 'add_suseconnect_product', 'get_addon_fullname';
use utils 'zypper_call';
use version_utils 'is_sle';

sub new {
    my ($class, $args) = @_;

    # Handle case where $args is a string (from openQA loader)
    if (!ref($args)) {
        $args = {name => $args};
    }

    # check mandatory attributes or bail out
    die "Attribute 'name' is mandatory" unless defined $args->{name};
    die "Attribute 'files' is mandatory" unless defined $args->{files};
    die "Attribute 'language' is mandatory" unless defined $args->{language};

    # check language support validity
    die "Unsupported language '$args->{language}'. Supported languages are 'go' and 'python'" unless $args->{language} =~ /^(go|python)$/;

    # Default values for attributes
    $args->{test_dir} //= '~/' . $args->{name};
    $args->{result_file} //= '/tmp/' . lc($args->{name}) . '_results.xml';
    $args->{data_url_path} //= 'security/' . $args->{name};
    $args->{run_command} //= './runtest';
    return bless $args, $class;
}

sub setup {
    my ($self) = @_;
    my $url = data_url($self->{data_url_path});
    my @files;
    if (ref($self->{files}) eq 'ARRAY') {
        @files = @{$self->{files}};
    } else {
        @files = split(' ', $self->{files});
    }
    zypper_call 'in go gotestsum' if $self->{language} eq 'go';
    zypper_call 'in python3-pytest' if $self->{language} eq 'python';
    assert_script_run 'mkdir -p ' . $self->{test_dir};
    assert_script_run 'cd ' . $self->{test_dir} . ' && curl -s ' . join(' ', map { "-O $url/$_" } @files);
    return $self;
}

sub run_test {
    my ($self) = @_;
    my $run_script = $self->{run_command};
    # Ensure run_command is treated as a path inside test_dir
    $run_script = "./$run_script" unless $run_script =~ m{^/|^\./};
    my $command = 'cd ' . $self->{test_dir} . ' && chmod +x ' . $run_script . ' && ' . $run_script . ' && mv results.xml ' . $self->{result_file};
    assert_script_run($command);
    return $self;
}

sub parse_results {
    my ($self) = @_;
    parse_extra_log('XUnit', $self->{result_file});
    return $self;
}

sub cleanup {
    my ($self) = @_;
    assert_script_run('rm -rf ' . $self->{test_dir});
    return $self;
}

1;
