# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Package: sqlite3 expect perl
# Summary: Test sqlite3 package
#   These tests use the sqlite3 commandline tool to test various SQL:
#   * CREATE/ALTER TABLE, CREATE INDEX, CREATE VIEW, CREATE TRIGGER
#   * INSERT, UPDATE
#   * SELECT (table and view)
#   * Test violating foreign keys and unique index
#   * Test trigger, view
#   * SAVEPOINT, ROLLBACK
#   * Interactive call with `expect`
# Maintainer: Tina Müller <tina.mueller@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils qw(is_transactional);
use transactional qw(trup_call check_reboot_changes);

sub run {
    my ($self) = @_;
    if (is_transactional) {
        select_console 'root-console';
        trup_call("pkg install sqlite3 expect perl");
        check_reboot_changes;
    } else {
        $self->select_serial_terminal;
        zypper_call('install sqlite3 expect perl');
    }

    my $archive = "sqlite3-tests.data";
    assert_script_run(
        sprintf "cd; curl -L -v %s/data/sqlite3 > %s && cpio -id < %s && mv data sqlite3 && ls sqlite3",
        autoinst_url(), $archive, $archive
    );

    # Test various commands
    my $tap_results = "sqlite3/results.tap";

    # --merge necessary so that STDERR doesn't accidentally land on top of
    # the file
    my $ret = script_run("prove --verbose --merge ./sqlite3/run-tests.t >$tap_results 2>&1");
    parse_extra_log(TAP => $tap_results);

    if ($ret) {
        die "./sqlite3/run-tests.t failed, see sqlite3/results.tap for details";
    }

    # Test interactive mode
    validate_script_output(
        "expect sqlite3/expect.sh",
        sub {
            m/
            sqlite>\ SELECT\ name,\ year\ FROM\ movie\ LIMIT\ 2;\r\n
            name\|year\r\n
            The\ Dead\ Don't\ Die\|2019\r\n
            Night\ on\ Earth\|1991\r\n
            sqlite>\ .quit
            /x
        },
    );

}

1;

