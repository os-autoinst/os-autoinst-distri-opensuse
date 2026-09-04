#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Generic helper for openQA-agnostic tests
#
# Runs standalone test artifacts (Go/Python/Java) both inside openQA
# and on a bare SUT. The 'domain' constructor arg controls which data/
# subtree test files are fetched from (e.g. 'security', 'console').
#
# Maintainer: QE Core <qe-core@suse.de>

package agnosticTestRunner;

use strict;
use warnings;
use testapi qw(assert_script_run data_url parse_extra_log script_output enter_cmd);
use registration 'add_suseconnect_product', 'get_addon_fullname';
use utils 'zypper_call';
use version_utils 'is_sle';

sub new {
    my ($class, $args) = @_;

    die "Constructor requires a hashref" unless ref($args) eq 'HASH';
    die "Attribute 'name' is mandatory" unless defined $args->{name};
    die "Attribute 'language' is mandatory" unless defined $args->{language};
    die "Unsupported language '$args->{language}'. Supported: go, python, java"
      unless $args->{language} =~ /^(go|python|java)$/;

    $args->{domain} //= 'security';
    $args->{test_dir} //= '~/' . $args->{name};
    $args->{result_format} //= $args->{language} eq 'java' ? 'TAP' : 'XUnit';
    $args->{result_file} //= '/tmp/' . lc($args->{name}) . ($args->{language} eq 'java' ? '_results.tap' : '_results.xml');
    $args->{data_url_path} //= $args->{domain} . '/openqa_agnostic/' . $args->{language} . '/' . $args->{name};
    $args->{helper_path} //= 'openqa_agnostic/lib/helper.sh';
    $args->{run_command} //= 'runtest';
    $args->{skip_phub} //= 0;
    return bless $args, $class;
}

sub latest_java_devel {
    my $out = script_output(
        q{zypper --terse -n se  'java-*-openjdk-devel'},
        proceed_on_failure => 1);
    my @majors = sort { $a <=> $b } ($out =~ /\bjava-(\d+)-openjdk-devel\b/g);
    die 'No java-*-openjdk-devel package available in configured repos' unless @majors;
    return "java-$majors[-1]-openjdk-devel";
}

sub setup {
    my ($self) = @_;
    my $url = data_url($self->{data_url_path});

    add_suseconnect_product(get_addon_fullname('phub')) if !$self->{skip_phub} && is_sle('<16.0');

    my %lang_deps = (go => 'go gotestsum', python => 'python3-pytest');
    my $packages = $self->{language} eq 'java' ? latest_java_devel() : $lang_deps{$self->{language}};
    zypper_call "in $packages";

    # Create test_dir and sibling lib/ for shared helpers in one shot
    my $test_dir = $self->{test_dir};
    assert_script_run "mkdir -p $test_dir/../lib";
    my $helper_url = data_url($self->{helper_path});
    assert_script_run "curl -s -o $test_dir/../lib/helper.sh $helper_url";

    # Download and discover test files via runtest -f
    my $run_script = $self->{run_command};
    assert_script_run "curl -s -o $test_dir/$run_script $url/$run_script";
    assert_script_run "chmod +x $test_dir/$run_script";

    my $file_list_output = script_output("cd $test_dir && ./$run_script -f");
    $file_list_output =~ s/^\s+|\s+$//g;
    if ($file_list_output) {
        my @files = split(/\s+/, $file_list_output);
        assert_script_run "cd $test_dir && curl -s " . join(' ', map { "-O $url/$_" } @files) if @files;
    }

    return $self;
}

sub run_test {
    my ($self) = @_;
    my $run_script = $self->{run_command};
    $run_script = "./$run_script" unless $run_script =~ m{^/|^\./};
    my $result_src = $self->{result_format} eq 'TAP' ? 'results.tap' : 'results.xml';
    my $command = 'cd ' . $self->{test_dir} . ' && chmod +x ' . $run_script . ' && ' . $run_script . ' && mv ' . $result_src . ' ' . $self->{result_file};
    assert_script_run($command);
    enter_cmd('reset');
    return $self;
}

sub parse_results {
    my ($self) = @_;
    parse_extra_log($self->{result_format}, $self->{result_file});
    return $self;
}

sub cleanup {
    my ($self) = @_;
    assert_script_run 'cd ~ && rm -rf ' . $self->{test_dir};
    return $self;
}

1;
