# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: gpg2 haveged
# Summary: GnuPG key generation and basic operation tests
# - Check the libgcrypt and libgcrypt20-hmac versions
# - Generate RSA keys with 1024, 2048, 3072 and 4096 bits (1024 must fail in
#   FIPS mode)
# - Encrypt, decrypt, sign and verify files
# - Restart and reload gpg-agent and verify the passphrase cache is dropped
#
# The functional part runs from data/console/openqa_agnostic/python/testGpg
# with loopback pinentry, so it needs no needles.
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#209268

use Mojo::Base 'opensusebasetest';
use testapi;
use Utils::Architectures 'is_s390x';
use Utils::Backends 'is_svirt';
use serial_terminal 'select_text_console';
use package_utils 'install_package';
use version_utils qw(is_sle is_public_cloud is_transactional is_sle_micro is_jeos);
use utils 'systemctl';
use security::gpg_utils 'check_libgcrypt';
use agnosticTestRunner;

sub prepare_gpg {
    install_package('gpg2', trup_apply => 1) if script_run('command -v gpg') != 0;

    my $gpg_fips_string = check_var('FIPS_ENABLED', '1') ? "fips-mode:y::Libgcrypt" : "fips-mode:n::";
    validate_script_output("gpgconf --show-versions", sub { m/.*$gpg_fips_string.*/ }) if (is_sle('15+') && !is_jeos && !is_public_cloud);

    # Increase entropy for key generation for s390x on the svirt backend
    my $is_sle15 = is_sle('15+') && is_sle('<16');
    my $is_transactional_and_slmicro_lt62 = is_transactional && is_sle_micro('<6.2');
    if (is_s390x && is_svirt && ($is_sle15 || $is_transactional_and_slmicro_lt62)) {
        install_package('haveged', trup_reboot => 1);
        systemctl('start haveged');
    }

    # NTP time sync, poo#191983
    if (is_sle('15+')) {
        my $chrony_status = systemctl('is-active chronyd', ignore_failure => 1);
        systemctl('start chronyd') if $chrony_status;
        assert_script_run('chronyc -a makestep | grep -E "^200 OK"');
    }

    my ($gpg_version) = script_output('gpg --version') =~ /gpg \(GnuPG\) (\S+)/;
    record_info('gpg version', "Version of Current gpg package: $gpg_version");

    return check_libgcrypt();
}

sub cleanup_gpg {
    script_run('for d in /tmp/testGpg-*; do [ -d "$d" ] && GNUPGHOME=$d gpgconf --kill all; done');
    script_run('rm -rf /tmp/testGpg-* ~/testGpg');
}

sub run {
    select_text_console;
    return if prepare_gpg();
    # trup reboots in prepare_gpg leave the VGA root console selected
    select_text_console;

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testGpg',
            domain => 'console',
            run_timeout => 900,
        }
    );
    $test->setup();
    # Exported after setup because installing pytest may reboot transactional
    # systems. The suite fails if the SUT FIPS state differs from the job's.
    my $expect_fips = (get_var('FIPS') || get_var('FIPS_ENABLED') || get_var('FIPS_ENV_MODE')) ? 1 : 0;
    assert_script_run("export GPG_EXPECT_FIPS=$expect_fips");
    $test->run_test()->parse_results()->cleanup();
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup_gpg;
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 0};
}

1;
