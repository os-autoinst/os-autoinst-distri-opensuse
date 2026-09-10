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
use testapi qw(assert_script_run data_url parse_extra_log script_output enter_cmd upload_logs record_info);
use Mojo::DOM;
use registration 'add_suseconnect_product', 'get_addon_fullname';
use package_utils 'install_package';
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
    install_package($packages, trup_reboot => 1);

    # Create test_dir and sibling lib/ for shared helpers in one shot
    my $test_dir = $self->{test_dir};
    assert_script_run("mkdir -p $test_dir/../lib", quiet => 1);
    my $helper_url = data_url($self->{helper_path});
    assert_script_run("curl -s -o $test_dir/../lib/helper.sh $helper_url", quiet => 1);

    # Download and discover test files via runtest -f
    my $run_script = $self->{run_command};
    assert_script_run("curl -s -o $test_dir/$run_script $url/$run_script", quiet => 1);
    assert_script_run("chmod +x $test_dir/$run_script", quiet => 1);

    my $file_list_output = script_output("cd $test_dir && ./$run_script -f", quiet => 1);
    $file_list_output =~ s/^\s+|\s+$//g;
    if ($file_list_output) {
        my @files = split(/\s+/, $file_list_output);
        assert_script_run("cd $test_dir && curl -s " . join(' ', map { "-O $url/$_" } @files), quiet => 1) if @files;
    }

    return $self;
}

sub run_test {
    my ($self) = @_;
    my $run_script = $self->{run_command};
    $run_script = "./$run_script" unless $run_script =~ m{^/|^\./};
    my $result_src = $self->{result_format} eq 'TAP' ? 'results.tap' : 'results.xml';
    my $name = $self->{name};
    my $output_log = "/tmp/${name}_output.log";
    my $command = 'cd ' . $self->{test_dir} . ' && chmod +x ' . $run_script
      . ' && ( set -o pipefail; ' . $run_script . " 2>&1 | tee $output_log )"
      . ' && mv ' . $result_src . ' ' . $self->{result_file};
    assert_script_run($command, quiet => 1);
    enter_cmd('reset');
    eval { upload_logs($output_log, failok => 1) };
    return $self;
}

sub parse_results {
    my ($self) = @_;
    parse_extra_log($self->{result_format}, $self->{result_file});

    my $content = script_output('cat ' . $self->{result_file}, quiet => 1);
    my $has_failures = 0;

    if ($self->{result_format} eq 'TAP') {
        for my $line (split /\n/, $content) {
            if ($line =~ /^ok\s+\d+\s*-?\s*(.*)/) {
                record_info("PASSED: $1", '', result => 'ok');
            } elsif ($line =~ /^not ok\s+\d+\s*-?\s*(.*)/) {
                $has_failures = 1;
                record_info("FAILED: $1", $line, result => 'fail');
            }
        }
    } else {
        my $dom = Mojo::DOM->new->xml(1)->parse($content);
        for my $tc ($dom->find('testcase')->each) {
            my $name = $tc->{name};
            my $failure = $tc->at('failure');
            if ($failure) {
                $has_failures = 1;
                my $msg = $failure->{message} || $failure->text || '';
                record_info("FAILED: $name", $msg, result => 'fail');
            } else {
                record_info("PASSED: $name", '', result => 'ok');
            }
        }
    }

    if ($has_failures) {
        $autotest::current_test->{result} = 'fail';
    }
    return $self;
}

sub cleanup {
    my ($self) = @_;
    assert_script_run('cd ~ && rm -rf ' . $self->{test_dir}, quiet => 1);
    return $self;
}

1;
