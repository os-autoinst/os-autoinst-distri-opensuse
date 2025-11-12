# SUSE's openQA tests
#
# Copyright 2018-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: python3-img-proof
# Summary: Use img-proof framework to test public cloud SUSE images
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use Path::Tiny;
use Mojo::JSON;
use publiccloud::utils qw(is_ondemand is_hardened);
use publiccloud::ssh_interactive 'select_host_console';
use File::Basename 'basename';
use version_utils "is_sle";

sub patch_json {
    my ($file) = @_;
    my $data = Mojo::JSON::decode_json(script_output("cat $file"));

    foreach my $i (0 .. $#{$data->{tests}}) {
        # Change "failed" to "passed"
        if ($data->{tests}[$i]{nodeid} =~ /^test_sles_hardened/ && $data->{tests}[$i]{outcome} eq 'failed') {
            $data->{tests}[$i]{outcome} = 'passed';
            record_soft_failure(get_var('PUBLIC_CLOUD_SOFTFAIL_SCAP', "bsc#1220269 - scap-security-guide fails"));
            my $json = Mojo::JSON::encode_json($data);
            assert_script_run "cat > $file <<EOF\n$json\nEOF";
            return;
        }
    }
}

sub analyze_results {
    my ($log, $output, $extra_test_results) = @_;
    my @runs;

    # parse the img-proof log by each test
    my $runs_count = 0;
    for my $line (split(/\n/, $log)) {
        last if ($line =~ /systemd\-analyze/);
        $runs_count = $runs_count + 1 if ($line =~ /session starts/);
        $line =~ s/={5,}/=====/g;
        $line =~ s/-{5,}/-----/g;
        $runs[$runs_count]{log} .= $line . "\n";
        if ($line =~ /([a-z_]+)\.py::([a-z_]+)\[paramiko:\/[0-9.]*-*([a-zA-Z-_]*)\] [a-zA-Z]+/) {
            $runs[$runs_count]->{name} = $1;
            $runs[$runs_count]->{test} .= $2 . "\n";
            $runs[$runs_count]->{param} .= $3 . "\n";
        }
    }

    # parse the output from img-proof by each test
    $runs_count = 0;
    for my $line (split(/\n/, $output)) {
        last if ($line =~ /Collecting basic info about VM/);
        next if ($line =~ /Testing soft reboot|Testing hard reboot|Testing refresh/);
        $runs_count = $runs_count + 1 if ($line =~ /Running test/);
        $runs[$runs_count]{output} .= $line . "\n";
    }

    # Alter the extra_test_results log files with output and log from img-proof
    for my $t (@{$extra_test_results}) {
        my $filename = 'result-' . $t->{name} . '.json';
        my $file = path(bmwqemu::result_dir(), $filename);
        my $json = Mojo::JSON::decode_json($file->slurp);
        my $logfile = path(bmwqemu::result_dir(), $json->{details}[0]->{text});
        for my $run (@runs) {
            if ($run->{name} ne '' && index($t->{name}, $run->{name}) != -1) {
                $logfile->append("\n\nimg-proof output:\n" . $run->{output});
                $logfile->append("\n\nimg-proof log:\n" . $run->{log});
            }
        }
    }
}

sub run {
    my ($self, $args) = @_;

    my $tests = get_var('PUBLIC_CLOUD_IMG_PROOF_TESTS', 'test-sles');
    my $provider;
    my $instance;

    select_host_console();

    unless ($args->{my_provider} && $args->{my_instance}) {
        $args->{my_provider} = $self->provider_factory();
        $args->{my_instance} = $args->{my_provider}->create_instance();
        $args->{my_instance}->wait_for_guestregister() if (is_ondemand);
    }
    $instance = $args->{my_instance};
    $provider = $args->{my_provider};

    # SLES 16 doesn't have AppArmor and stores ssh configuration in /usr/etc
    if (is_hardened && is_sle("<16")) {
        # Fix permissions for /etc/ssh/sshd_config
        # https://bugzilla.suse.com/show_bug.cgi?id=1219100
        $instance->ssh_assert_script_run('sudo chmod 600 /etc/ssh/sshd_config');
        # Avoid "pam_apparmor(sudo:session): Unknown error occurred changing to root hat: Operation not permitted"
        $instance->ssh_assert_script_run('sudo sed -i /pam_apparmor.so/d /etc/pam.d/*');
    }

    if ($tests eq "default") {
        record_info("Deprecated setting", "PUBLIC_CLOUD_IMG_PROOF_TESTS should not use 'default' anymore. Please use 'test_sles' instead.", result => 'softfail');
        $tests = "test_sles";
    }

    if (get_var('IMG_PROOF_GIT_REPO')) {
        my $repo = get_required_var('IMG_PROOF_GIT_REPO');
        my $branch = get_required_var('IMG_PROOF_GIT_BRANCH');
        assert_script_run "zypper rm -y python3-img-proof python3-img-proof-tests";
        assert_script_run "git clone --depth 1 -q --branch $branch $repo";
        assert_script_run "cd img-proof";
        assert_script_run "python3 setup.py install";
        assert_script_run "cp -r usr/* /usr";
    }

    my $img_proof = $provider->img_proof(
        instance => $instance,
        tests => $tests,
        results_dir => 'img_proof_results',
        exclude => get_var("PUBLIC_CLOUD_IMG_PROOF_EXCLUDE", ''),
        beta => get_var("BETA", 0)
    );

    # Because the IP address of instance might change during img_proof due to the hard-reboot, we need to re-add the ssh public keys
    my $ssh_dir = "~/.ssh";
    assert_script_run("mkdir -m 700 -p $ssh_dir");
    assert_script_run("touch $ssh_dir/known_hosts");

    assert_script_run(sprintf('ssh-keyscan %s >> %s/known_hosts', $instance->public_ip, $ssh_dir));

    if (is_hardened() && !check_var('SCAP_REPORT', 'skip')) {
        # Add soft-failure for https://bugzilla.suse.com/show_bug.cgi?id=1220269
        patch_json $img_proof->{results} if (get_var('PUBLIC_CLOUD_SOFTFAIL_SCAP'));
    }

    upload_logs($img_proof->{logfile}, log_name => basename($img_proof->{logfile}) . ".txt");

    parse_extra_log(IPA => $img_proof->{results});

    $instance->ssh_script_run(cmd => 'sudo chmod a+r /var/tmp/report.html || true', no_quote => 1);
    $instance->upload_log('/var/tmp/report.html', failok => 1);

    my $log = script_output('cat ' . $img_proof->{logfile});
    eval { analyze_results($log, $img_proof->{output}, $self->{extra_test_results}) };

    assert_script_run('rm -rf img_proof_results');

    # fail, if at least one test failed
    if ($img_proof->{fail} > 0) {
        $instance->run_ssh_command(cmd => 'rpm -qa > /tmp/rpm_qa.txt', no_quote => 1);
        upload_logs('/tmp/rpm_qa.txt');
        $instance->run_ssh_command(cmd => 'sudo journalctl -b > /tmp/journalctl_b.txt', no_quote => 1);
        upload_logs('/tmp/journalctl_b.txt');
        die('img_proof failed');
    }
}

sub cleanup {
    my ($self) = @_;
    # upload logs on unexpected failure
    my $ret = script_run('test -d img_proof_results');
    if (defined($ret) && $ret == 0) {
        assert_script_run('tar -zcvf img_proof_results.tar.gz img_proof_results');
        upload_logs('img_proof_results.tar.gz', failok => 1);
    }
    return 1;
}

1;

=head1 Discussion

This module use img-proof tool to test public cloud SLE images.
Logs are uploaded at the end.

When running img-proof from SLES, it must have a valid SCC registration to enable
public cloud module.

The variables DISTRI, VERSION and ARCH must correspond to the system where
img-proof get installed in and not to the public cloud image.
