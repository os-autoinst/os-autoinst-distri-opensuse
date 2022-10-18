# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Use the created hdd and run the external testkits in offline mode.
# * Go to the directory testdir and untar the external testkits
# * Ensure that the network is not available
# * Start the test by running the systemd_pepare.sh
# * Run the systemd_run.sh and save the result
# * Make sure that network is still down
# * Parse the saved result and return the status
# Verify the output of the external testkits run.
# Maintainer: QE Core <qe-core@suse.de>
# Tags: poo#106284

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Mojo::JSON qw(encode_json);
use version_utils qw(is_sle);
use strict;
use warnings;
use Utils::Logging;

my $log = '/tmp/systemd_run.log';
my $testdir = '/usr/lib/test/external/';

sub run {
    my ($self) = @_;
    select_serial_terminal;
    assert_script_run("cd $testdir");
    assert_script_run("tar -zxvf systemd_suse.tgz");
    # Make the Network offline if OFFLIE_SUT is set to 1
    # To be common criteria compliant, binaries not controlled by SUSE must be excecuted isolated
    # hence the reason to disable the network here, beyond this step, treat the machine as tainted.
    assert_script_run(qq{(ping -c4 build.suse.de && exit 1 || exit 0 )});
    assert_script_run(qq{(ping -c4 8.8.8.8 && exit 1 || exit 0)});
    record_info("START", "Testsuite execution is starting");
    assert_script_run "cp systemd/*.sh .";
    assert_script_run 'sh -e ./systemd_prepare.sh';
    # Wait at least 180s for test to finish
    my $wait = 180;
    # Run the test and save the logs and results
    # systemd_run.sh will fail with a non-zero retval if any of the sub-tests
    # fail. We ignore it to parse the individual results from the log
    my $out = script_output "su - abcadm -c '$testdir/systemd_run.sh' 2>&1 | tee $log", $wait, proceed_on_failure => 1;
    record_info("END", "Testsuite excecution finished");
    record_info("TEST LOG", "$out");
    assert_script_run(qq{(ping -c4 build.suse.de && exit 1 || exit 0 )});
    assert_script_run(qq{(ping -c4 8.8.8.8 && exit 1 || exit 0)});
    # Parse the result of each sub test after running systemd_run.sh
    # Test verifies the saved results and returns result information.
    $self->parse_results_from_output($out);
    $self->upload_systemdlib_tests_logs;
}

sub parse_results_from_output {
    my ($self, $out) = @_;
    my $results_file = 'systemd_run.results';
    my $distro = uc(get_required_var('DISTRI'));
    my $testunit = '';
    my $outcome = '';
    my $error_line = '';
    my %results = (
        tests => [],
        info => {timestamp => 0, distro => $distro, results_file => $results_file},
        summary => {duration => 0, passed => 0, num_tests => 0});

    $out =~ s/\r//gs;
    foreach my $line (split(/\n/, $out)) {
        if ($line =~ /^\/home.+\/([a-z0-9]+)\/run_test.sh$/) {
            # Test block started. Identify test unit name and assume test will pass
            $testunit = $1;
            $outcome = 'passed';
            next;
        }

        if ($line =~ /(ERROR:|FAILED:|failed$)/) {
            $outcome = 'failed';
            $error_line = $line;
        }

        if ($testunit && ($line =~ /(^=+$|^#+$)/)) {
            # Test block end has been reached. Record results

            if ($outcome eq 'failed') {
                # In case you need to add soft failure, use the following commented code as a guide
                #my ($openQA_result, $softfail_result);
                #if ($error_line =~ /problems.*hostagent.service/) {
                #   $openQA_result = $self->record_testresult('softfail');
                #   $softfail_result = 119565;
                #} else {
                my ($openQA_result, $softfail_result);
                if ($error_line =~ /invalid version.*expected.*/ && is_sle('=15-SP5')) {
                    $openQA_result = $self->record_testresult('softfail');
                    $softfail_result = 1203060;
                }
                else {
                    my $openQA_result = $self->record_testresult('fail');
                    #$softfail_result = 0;
                    #}
                    $softfail_result = 0;
                }
                my $openQA_filename = $self->next_resultname('txt');
                $openQA_result->{title} = $testunit;
                $openQA_result->{text} = $openQA_filename;
                #($softfail_result) ? $self->write_resultfile($openQA_filename, "# Softfail bsc#$softfail_result:\n$error_line\n") :
                ($softfail_result)
                  ? $self->write_resultfile($openQA_filename, "# Softfail bsc#$softfail_result:\n$error_line\n")
                  : $self->write_resultfile($openQA_filename, "# Failure:\n$error_line\n");
                $self->{dents}++;
            }

            $results{summary}{num_tests}++;
            $results{summary}{passed}++ if ($outcome eq 'passed');
            push @{$results{tests}}, {nodeid => $testunit, test_index => 0, outcome => $outcome};
            $testunit = '';
            $outcome = '';
            $error_line = '';
        }

        last if ($line =~ /^### JOURNALCTL/);
    }

    my $json = encode_json \%results;
    record_info("IPA Results", $json);
    assert_script_run "echo '$json' > /tmp/$results_file";
}

sub upload_systemdlib_tests_logs {
    my ($self) = @_;
    my $out = script_output('journalctl --no-pager -axb -o short-precise');
    record_info("JOURNAL", "$out");
    my $filename = "start_external_testkit_offline.log";
    save_ulog($out, $filename);
}

1;
