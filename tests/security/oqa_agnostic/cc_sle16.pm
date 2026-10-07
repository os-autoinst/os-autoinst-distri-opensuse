# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run SLES EAL4+ SLE 16 Common Criteria check/apply verification.
#
#   Step 2: run 'check' - record initial CC compliance status
#   Step 3: run 'apply' - apply CC settings; download /var/log/cc-* logs
#   Step 4: reboot, run 'check' again - verify CC compliance after apply
#   Step 5: leave ~/certification-sles-eal4-16.0 with the check/apply scripts in homedir
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#207705

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use power_action_utils 'power_action';
use agnosticTestRunner;
use version_utils 'is_sle';
use package_utils 'install_package';
use registration qw(add_suseconnect_product get_addon_fullname);
use security::sle16cc 'unlock_and_login_cc_system';

# The check and apply scripts are stored in data/security/sle16_cc/
use constant CC_DATA_DIR => 'security/sle16_cc';
use constant CC_SCRIPTS => qw(check apply);
use constant CC_REPO_DIR => '~/certification-sles-eal4-16.0';

sub _make_runner {
    my ($phase, $timeout) = @_;
    $timeout //= 300;
    # Set CC_PHASE in the SUT environment so runtest selects the right pytest marks
    assert_script_run("export CC_PHASE=$phase");
    return agnosticTestRunner->new({
            language => 'python',
            name => 'testCCSLE16',
            domain => 'security',
            run_timeout => $timeout,
        }
    );
}

sub run {
    my ($self) = @_;

    select_serial_terminal;

    if (!is_sle('>=16')) {
        record_info('SKIP', 'CC SLE16 verification is only applicable to SLE 16 and later');
        return;
    }
    # Install pam_ssh - needed for CC
    add_suseconnect_product(get_addon_fullname('phub'));
    assert_script_run('zypper --gpg-auto-import-keys refresh');
    install_package('pam_ssh', trup_apply => 1);

    # Step 5 (download): put the CC check/apply scripts into the home directory.
    # They serve both as the tools for steps 2-4 and as the persistent copy
    # left on the SUT for auditors after the test.
    assert_script_run('mkdir -p ' . CC_REPO_DIR);
    for my $script (CC_SCRIPTS) {
        assert_script_run("curl -sf -o " . CC_REPO_DIR . "/$script " . data_url(CC_DATA_DIR . "/$script"));
    }
    assert_script_run('chmod +x ' . join(' ', map { CC_REPO_DIR . "/$_" } CC_SCRIPTS));
    record_info('CC scripts', script_output('sha256sum ' . join(' ', map { CC_REPO_DIR . "/$_" } CC_SCRIPTS)));

    # Step 2: run 'check' - record initial status (pre-apply)
    # Step 3: run 'apply' - apply CC settings
    my $runner_pre = _make_runner('pre', 300);
    $runner_pre->setup()->run_test()->parse_results()->cleanup();

    # Step 3 (cont.): upload /var/log/cc-* logs produced by apply
    assert_script_run('ls /var/log/cc-* 2>/dev/null || true');
    script_run('tar czf /tmp/cc-logs.tar.gz /var/log/cc-* 2>/dev/null || true');
    upload_logs('/tmp/cc-logs.tar.gz', failok => 1);

    # Step 4: reboot, then run 'check' again
    # The CC system has its own disk encryption, grub and login screens,
    # so wait_boot can not be used.
    power_action('reboot', textmode => 1);
    unlock_and_login_cc_system(get_var('USERNAME', $testapi::username), get_var('DEFAULT_PASSWORD', $testapi::password));
    select_serial_terminal;

    my $runner_post = _make_runner('post', 300);
    $runner_post->setup()->run_test()->parse_results()->cleanup();

    # CC_REPO_DIR is intentionally NOT cleaned up (step 5 - leave clone in homedir)
    record_info('CC repo retained', CC_REPO_DIR . ' left in homedir as per step 5');
}

sub post_fail_hook {
    my ($self) = @_;
    # Collect any CC logs produced before the failure
    script_run('tar czf /tmp/cc-logs-fail.tar.gz /var/log/cc-* 2>/dev/null || true');
    upload_logs('/tmp/cc-logs-fail.tar.gz', failok => 1);
    $self->SUPER::post_fail_hook;
}

1;
