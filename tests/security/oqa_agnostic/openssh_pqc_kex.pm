# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: openssh-clients openssh-server crypto-policies-scripts
# Summary: Check the OpenSSH ML-KEM / NIST P-256 hybrid key exchange
# - Install the packages and log the package versions, the FIPS mode,
#   the crypto-policy and the SELinux mode
# - Run the testOpenSSHPQCKex pytest suite from
#   data/security/openqa_agnostic/python/testOpenSSHPQCKex with the
#   active crypto-policy
# - Without FIPS, set the BSI crypto-policy, run the suite again and
#   restore the original policy. A reboot is not necessary: the suite
#   starts new sshd and ssh processes, which read the policy at start.
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#210513, jsc#PED-17037

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use agnosticTestRunner;

my %runner_args = (
    language => 'python',
    name => 'testOpenSSHPQCKex',
    domain => 'security',
    run_timeout => 600,
);
my $original_policy;
my @suite_ids;

sub run {
    my ($self) = @_;
    select_serial_terminal;
    zypper_call('in openssh-clients openssh-server crypto-policies-scripts');
    $original_policy = active_policy();
    my $fips = script_output('cat /proc/sys/crypto/fips_enabled') eq '1';
    # getenforce is not on minimal installations
    my %selinux_modes = (1 => 'enforcing', 0 => 'permissive');
    my $selinux = script_output('cat /sys/fs/selinux/enforce 2>/dev/null || echo disabled');
    record_info('Environment', join("\n",
            script_output('rpm -q openssh openssh-clients openssh-server crypto-policies', proceed_on_failure => 1),
            'FIPS mode: ' . ($fips ? 'enabled' : 'disabled'),
            "Crypto-policy: $original_policy",
            'SELinux: ' . ($selinux_modes{$selinux} // $selinux)));
    record_info('Policy KEX', script_output('grep -H KexAlgorithms /etc/crypto-policies/back-ends/openssh*.config', proceed_on_failure => 1));

    my $setup = agnosticTestRunner->new({%runner_args})->setup();
    return if $setup->{skipped};

    run_suite($original_policy);
    if ($fips || $original_policy =~ /^FIPS/) {
        record_info('BSI skipped', 'The BSI crypto-policy is not used in FIPS mode');
    }
    elsif ($original_policy eq 'BSI') {
        record_info('BSI skipped', 'The BSI crypto-policy is already active');
    }
    elsif (script_run('test -f /usr/share/crypto-policies/policies/BSI.pol') != 0) {
        record_info('BSI skipped', 'The crypto-policies package does not ship the BSI policy');
    }
    else {
        set_policy('BSI');
        record_info('sshd BSI KEX', script_output('sshd -T 2>&1 | grep -i ^kexalgorithms', proceed_on_failure => 1));
        run_suite('BSI');
        set_policy($original_policy);
    }
    $setup->cleanup();
}

sub active_policy {
    my $policy = script_output('update-crypto-policies --show 2>/dev/null');
    die "Unexpected crypto-policy name '$policy'" unless $policy =~ /^[A-Z0-9:._-]+$/;
    return $policy;
}

sub set_policy {
    my ($policy) = @_;
    assert_script_run("update-crypto-policies --set $policy");
    my $active = active_policy();
    die "The crypto-policy is '$active' after setting '$policy'" unless $active eq $policy;
}

sub run_suite {
    my ($policy) = @_;
    # The openQA XUnit parser drops the part of the name after the first
    # dot: use one name without dots per policy, in the same test directory
    (my $id = $policy) =~ tr/.:-/___/;
    push @suite_ids, $id;
    agnosticTestRunner->new({
            %runner_args,
            name => "testOpenSSHPQCKex_$id",
            test_dir => '~/testOpenSSHPQCKex',
            result_file => "/tmp/openssh_pqc_kex_$id.xml",
    })->run_test()->parse_results();
}

# Also runs when parse_results() only marks the module as failed
sub post_fail_hook {
    my ($self) = @_;
    # Do not let an error here prevent the default log collection
    eval {
        select_serial_terminal;
        # run_test() dies when runtest fails: do not leave the system on BSI
        script_run("update-crypto-policies --set $original_policy") if $original_policy;
        upload_logs("/tmp/testOpenSSHPQCKex_${_}_output.log", failok => 1) for @suite_ids;
        my $denials = 'if command -v ausearch >/dev/null; then ausearch -m AVC,USER_AVC,SELINUX_ERR -ts recent; '
          . "else journalctl -b -o cat --no-pager | grep -i 'avc:' | tail -n 50; fi";
        record_info('SELinux denials', script_output("($denials) 2>&1", proceed_on_failure => 1));
    };
    record_info('post_fail_hook', "Collecting the test logs failed: $@") if $@;
    $self->SUPER::post_fail_hook;
}

1;
