# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: MozillaFirefox core packaging smoke test via Marionette
# Maintainer: QE Core <qe-core@suse.com>

use Mojo::Base 'consoletest';
use testapi;
use utils 'zypper_call';
use serial_terminal 'select_serial_terminal';
use python_version_utils 'get_python3_binary';
use version_utils qw(is_sle is_transactional);
use package_utils 'install_package';
use transactional 'reboot_on_changes';

sub run {
    select_serial_terminal;
    record_info('Install', 'Install MozillaFirefox and source for testsuite');
    # looking for latest python3**-psutil e.g. python-311 because it's required on s390x
    my $latest_python = script_output(q(zypper se '/^python3[0-9][0-9]-psutil$/' | awk -F '|' '/python3[0-9][0-9]-psutil/ ) .
          q({ if (match($2, /python3[0-9][0-9]/)) print substr($2, RSTART, RLENGTH) }' | tail -n1));
    my $python_bin = get_python3_binary($latest_python);
    install_package("MozillaFirefox $latest_python ${latest_python}-pip ${latest_python}-wheel ${latest_python}-psutil", trup_reboot => 1);
    my $version = get_var('VERSION');
    zypper_call("mr -e SLE-Product-SLES-$version-Source") if is_sle('16+');
    # add source repo from INCIDENT_REPO
    if (check_var('FLAVOR', 'Online-Updates-Staging') || check_var('FLAVOR', 'Online-Immutable-Updates-Staging')) {
        my @repos = split(/,/, get_var('INCIDENT_REPO', ''));
        while (my ($i, $repo) = each(@repos)) {
            chop $repo if $repo =~ /\/$/;
            zypper_call("ar -f $repo-Source/ TEST_${i}_Source");
        }
        zypper_call('--gpg-auto-import-keys ref') if check_var('FLAVOR', 'Online-Immutable-Updates-Staging');
    }
    zypper_call('-v si -D MozillaFirefox');
    reboot_on_changes if is_transactional;
    zypper_call("mr -d SLE-Product-SLES-$version-Source") if is_sle('16+');
    script_run('rm -f /etc/zypp/repos.d/TEST_*_Source.repo') if check_var('FLAVOR', 'Online-Updates-Staging') || check_var('FLAVOR', 'Online-Immutable-Updates-Staging');
    my $ff_version = script_output('firefox --version');
    my ($ff_major) = $ff_version =~ /Firefox\s+(\d+)/;
    record_info('Firefox version', $ff_version);
    record_info('Python version', $latest_python);
    record_info('Prepare', 'Prepare test env, requirements etc.');
    assert_script_run('cd /usr/src/packages/SOURCES/');
    assert_script_run('tar -xf firefox-*.source.tar.xz -C /root --wildcards "*/testing/mozbase*" "*/testing/marionette*"');
    assert_script_run('cd /root/firefox-*/');
    assert_script_run("$python_bin -m venv --system-site-packages .venv && source .venv/bin/activate");
    assert_script_run('pip install --upgrade pip');
    assert_script_run('for p in testing/mozbase/* testing/marionette/*; do ' .
          'if [ -f "$p/setup.py" ] || [ -f "$p/pyproject.toml" ]; then pip install "$p"; fi; done', timeout => 300);
    assert_script_run('export MOZ_HEADLESS_WIDTH=1024 MOZ_HEADLESS_HEIGHT=768');
    my $test_target;
    my $unit_dir = 'testing/marionette/harness/marionette_harness/tests/unit';
    # old FF version 140 has many failures, run only few tests
    if ($ff_major < 153) {
        my @core_tests = (
            "$unit_dir/test_navigation.py",
            "$unit_dir/test_click.py",
        );
        $test_target = join(' ', @core_tests);
    }
    else {
        # exclude known failing tests
        assert_script_run(qq(sed -i '/test_marionette.py/a disabled = "failing"' $unit_dir/unit-tests.toml));
        assert_script_run(qq(sed -i '/test_reftest.py/a disabled = "failing"' $unit_dir/unit-tests.toml));
        assert_script_run(qq(sed -i '/test_screenshot.py/a disabled = "failing"' $unit_dir/unit-tests.toml));
        $test_target = "$unit_dir/unit-tests.toml";
    }
    my $cmd = "marionette --headless --binary /usr/bin/firefox --log-xunit=results.xml --log-raw=marionette.log $test_target";
    record_info('Testsuite', 'Run core Marionette tests');
    assert_script_run($cmd, timeout => 1500);
    upload_logs('results.xml');
    parse_junit_log('results.xml');
}

sub post_fail_hook {
    my ($self) = @_;
    upload_logs('results.xml');
    upload_logs('marionette.log');
    parse_junit_log('results.xml');
    $self->SUPER::post_fail_hook;
}

1;
