# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: opencode
# Summary: Test the opencode terminal AI coding agent against a local stub provider
# Maintainer: Martin Pluskal <martin@pluskal.org>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use utils 'script_retry';

my $workdir = '/tmp/opencode-test';
my $stub = '/tmp/opencode-stub.py';
my $stub_log = '/tmp/opencode-stub.log';
my $stderr_log = '/tmp/opencode-stderr.log';
my $port = 18080;
my $reply = 'OPENQA_STUB_OK';

# stdin is closed because opencode reads it whenever it is not a terminal, and
# stdout is piped because it only writes the bare answer there when it is not
# one: on a console it decorates the answer onto stderr instead, which no
# assertion could then match. stderr is kept in a file the failure hook uploads.
# The XDG directories are redirected so the session store cannot outlive the test.
sub opencode {
    my ($args) = @_;
    return
      "env HOME=$workdir XDG_CONFIG_HOME=$workdir/config XDG_DATA_HOME=$workdir/data "
      . "XDG_CACHE_HOME=$workdir/cache XDG_STATE_HOME=$workdir/state "
      . "OPENCODE_DISABLE_MODELS_FETCH=1 OPENCODE_DISABLE_AUTOUPDATE=1 OPENCODE_DISABLE_PROJECT_CONFIG=1 "
      . "opencode $args </dev/null 2>>$stderr_log | cat";
}

sub run {
    select_serial_terminal;

    install_package('opencode', trup_apply => 1) if script_run('rpm -q opencode');
    record_info('package', script_output('rpm -q opencode'));

    # a mis-stripped binary reports the bun runtime's version instead of its own
    my $version = script_output(q(rpm -q --queryformat '%{VERSION}' opencode));
    validate_script_output('opencode --version', sub { m/^\Q$version\E$/ });
    validate_script_output('opencode --help 2>&1', sub { m/\brun\b/ });

    assert_script_run "mkdir -p $workdir/config/opencode";
    assert_script_run 'curl -f -o ' . $stub . ' ' . data_url('opencode/stub_server.py');
    assert_script_run 'curl -f -o ' . "$workdir/config/opencode/opencode.json " . data_url('opencode/opencode.json');
    assert_script_run "(setsid python3 $stub --port $port --reply $reply --log $stub_log >/dev/null 2>&1 &)";
    script_retry("curl -sf http://127.0.0.1:$port/v1/models", delay => 2, retry => 15,
        fail_message => 'stub provider did not answer');

    assert_script_run opencode('models') . " | grep -qx 'stub/stub-model'", timeout => 120;

    # opencode falls back to a hosted model when it cannot use the configured
    # provider, so the assertions below are on the canned reply: a real model
    # would answer something else and the fallback would be caught here.
    validate_script_output opencode("run -m stub/stub-model 'say hello'"),
      sub { m/^\Q$reply\E$/ }, timeout => 180;

    my $json = script_output opencode("run -m stub/stub-model --format json 'say hello'"), timeout => 180;
    die 'no text event carrying the stub reply in the json stream'
      unless $json =~ /"type":"text".*\Q$reply\E/;
    record_info('round trip', "the stub provider answered $reply in both output formats");
}

sub cleanup {
    script_run "pkill -f $stub";
    script_run "rm -rf $workdir $stub $stderr_log";
}

sub post_run_hook {
    my ($self) = @_;
    cleanup();
    $self->SUPER::post_run_hook;
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    upload_logs($stub_log, failok => 1);
    upload_logs($stderr_log, failok => 1);
    upload_logs("$workdir/data/opencode/log/opencode.log", failok => 1);
    cleanup();
}

sub test_flags { return {fatal => 0, no_rollback => 1}; }

1;
