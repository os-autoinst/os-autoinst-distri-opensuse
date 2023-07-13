# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: install and execute the external systemd lib sapstart
# test script. Parse and upload the results so they are presented
# as External Results.
# - Determine the repository where the external systemd lib sapstart
#   test script is located or use the one provided in the
#   QA_TEST_REPO setting. If the setting points to a tarball, use the
#   tarball directly instead.
# - Add the repository and install the SAP-systemdlib-tests package.
# - Prepare and run the external test script.
# - Collect the results and format them in JSON so they can be added
#   to the report with testapi::parse_extra_log()
# - Upload results and logs.
# Maintainer: Alvaro Carvajal <acarvajal@suse.com>

use base 'consoletest';
use testapi;
use utils;
use version_utils qw(is_sle is_opensuse is_tumbleweed);
use Mojo::JSON qw(encode_json);
use strict;
use warnings;
use Utils::Logging qw(save_and_upload_log tar_and_upload_log);

my $log = '/tmp/systemd_run.log';
my $testdir = '/usr/lib/systemd/test/SAP';

sub install_test_package {
    my ($self) = @_;
    my $version = get_required_var('VERSION');
    my $qatest_repo = get_var('QA_TEST_REPO', '');
    my $repo_name = 'SAP-systemdlib-testrepo';
    my $pkg_name = 'SAP-systemdlib-tests';

    if (!$qatest_repo) {
        if (is_opensuse()) {
            my $sub_project;
            if (is_tumbleweed()) {
                $sub_project = 'Tumbleweed/openSUSE_Tumbleweed/';
            }
            else {
                (my $version, my $service_pack) = split('\.', $version);
                $sub_project = "Leap:/$version/openSUSE_Leap_$version.$service_pack/";
            }
            $qatest_repo = 'https://download.opensuse.org/repositories/devel:/openSUSE:/QA:/' . $sub_project;
        }
        else {
            $qatest_repo = "http://download.suse.de/ibs/QA:/Head/SLE-$version/";
        }
        die '$qatest_repo is not set' unless ($qatest_repo);
    }

    if ($qatest_repo =~ m/(\.tar|\.tgz)/) {
        my $zopt = ($qatest_repo =~ m/gz$/) ? 'z' : '';
        enter_cmd "mkdir -p $testdir";
        enter_cmd "cd $testdir";
        assert_script_run "curl -k $qatest_repo | tar -${zopt}xvf -";
        assert_script_run "cp systemd/*.sh .";
        enter_cmd "cd -";
    }
    else {
        # Assume test repo is a zypper repository
        zypper_ar $qatest_repo, name => $repo_name;
        zypper_call "in $pkg_name";
    }
}

sub parse_results_from_output {
    my ($self, $out) = @_;
    my $results_file = 'systemd_run.results';
    my $distro = uc(get_required_var('DISTRI'));
    my $testunit = '';
    my $outcome = '';
    my %results = (
        tests => [],
        info => {timestamp => 0, distro => $distro, results_file => $results_file},
        summary => {duration => 0, passed => 0, num_tests => 0}
    );

    $out =~ s/\r//gs;
    foreach my $line (split(/\n/, $out)) {
        if ($line =~ /^\/home.+\/([a-z0-9]+)\/run_test.sh$/) {
            # Test block started. Identify test unit name and assume test will pass
            $testunit = $1;
            $outcome = 'passed';
            next;
        }
        $outcome = 'failed' if ($line =~ /(ERROR:|FAILED:|failed$)/);
        if ($testunit && ($line =~ /(^=+$|^#+$)/)) {
            # Test block end has been reached. Record results
            $results{summary}{num_tests}++;
            $results{summary}{passed}++ if ($outcome eq 'passed');
            push @{$results{tests}}, {nodeid => $testunit, test_index => 0, outcome => $outcome};
            $testunit = '';
            $outcome = '';
        }
        last if ($line =~ /^### JOURNALCTL/);
    }

    my $json = encode_json \%results;
    assert_script_run "echo '$json' > /tmp/$results_file";
    parse_extra_log(IPA => "/tmp/$results_file");
}

sub upload_systemdlib_tests_logs {
    my ($self) = @_;
    tar_and_upload_log($log, "$log.tar.bz2");
    save_and_upload_log('journalctl --no-pager -axb -o short-precise', 'journal.txt');
}

sub run {
    my ($self) = @_;

    select_console 'root-console';
    $self->install_test_package;
    enter_cmd "cd $testdir";
    # systemd_prepare.sh can fail with a 0 retval, so we run it with sh -e
    # to attempt to catch any errors and abort if necessary
    assert_script_run 'sh -e ./systemd_prepare.sh';
    # Wait at least 180s for test to finish
    my $wait = 180;
    # Run the test and save the logs and results
    # systemd_run.sh will fail with a non-zero retval is any of the sub-tests
    # fail. We ignore it to parse the individual results from the log
    my $out = script_output "su - abcadm -c '$testdir/systemd_run.sh' 2>&1 | tee $log", $wait, proceed_on_failure => 1;
    $self->parse_results_from_output($out);
    $self->upload_systemdlib_tests_logs;
}

sub post_fail_hook {
    my ($self) = @_;
    #upload logs from given testname
    tar_and_upload_log('/var/log/journal /run/log/journal', 'binary-journal-log.tar.bz2');
    $self->upload_systemdlib_tests_logs;
}

1;
