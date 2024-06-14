# SUSE's openQA tests
#
# Copyright 2018-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: python3-img-proof
# Summary: Use img-proof framework to test public cloud SUSE images
#
# Maintainer: <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use Mojo::File 'path';
use Mojo::JSON;
use publiccloud::utils qw(is_ondemand is_hardened);
use publiccloud::ssh_interactive 'select_host_console';
use version_utils 'is_sle';
use File::Basename 'basename';

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

sub run {
    my ($self, $args) = @_;

    my $tests = get_var('PUBLIC_CLOUD_IMG_PROOF_TESTS', 'test-sles');
    my $provider;
    my $instance;

    select_host_console();

    # QAM passes the instance as argument
    if (get_var('PUBLIC_CLOUD_QAM')) {
        $instance = $args->{my_instance};
        $provider = $args->{my_provider};
    } else {
        $provider = $self->provider_factory();
        $instance = $provider->create_instance(check_guestregister => is_ondemand ? 1 : 0);
    }

    if (is_hardened) {
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
    assert_script_run(sprintf('ssh-keyscan %s >> ~/.ssh/known_hosts', $instance->public_ip));

    if (is_hardened) {
        # Add soft-failure for https://bugzilla.suse.com/show_bug.cgi?id=1220269
        patch_json $img_proof->{results}; # if (get_var('PUBLIC_CLOUD_SOFTFAIL_SCAP'));
    }

    upload_logs($img_proof->{logfile}, log_name => basename($img_proof->{logfile}) . ".txt");
    parse_extra_log(IPA => $img_proof->{results});
    assert_script_run('rm -rf img_proof_results');

    $instance->ssh_script_run(cmd => 'sudo chmod a+r /var/tmp/report.html || true', no_quote => 1);
    $instance->upload_log('/var/tmp/report.html', failok => 1);

    # fail, if at least one test failed
    if ($img_proof->{fail} > 0) {

        # Upload cloudregister log if corresponding test fails
        for my $t (@{$self->{extra_test_results}}) {
            next if ($t->{name} !~ m/registration|repo|smt|guestregister|update/);
            my $filename = 'result-' . $t->{name} . '.json';
            my $file = path(bmwqemu::result_dir(), $filename);
            my $json = Mojo::JSON::decode_json($file->slurp);
            next if ($json->{result} ne 'fail');
            $instance->upload_log('/var/log/cloudregister', log_name => 'cloudregister.txt');
            last;
        }
        $instance->run_ssh_command(cmd => 'rpm -qa > /tmp/rpm_qa.txt', no_quote => 1);
        upload_logs('/tmp/rpm_qa.txt');
        $instance->run_ssh_command(cmd => 'sudo journalctl -b > /tmp/journalctl_b.txt', no_quote => 1);
        upload_logs('/tmp/journalctl_b.txt');
    }

    if (is_hardened) {
        # Upload SCAP profile used by img-proof
        my $url = "https://ftp.suse.com/pub/projects/security/oval/suse.linux.enterprise.15.xml.gz";
        assert_script_run("curl --fail -LO $url");
        upload_logs("suse.linux.enterprise.15.xml.gz");
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
}

1;

=head1 Discussion

This module use img-proof tool to test public cloud SLE images.
Logs are uploaded at the end.

When running img-proof from SLES, it must have a valid SCC registration to enable
public cloud module.

The variables DISTRI, VERSION and ARCH must correspond to the system where
img-proof get installed in and not to the public cloud image.

