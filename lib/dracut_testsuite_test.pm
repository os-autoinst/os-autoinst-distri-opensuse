# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: library functions for setting up the tests and uploading logs in case of error.
# Maintainer: dracut maintainers <dracut-maintainers@suse.de>

package dracut_testsuite_test;
use warnings;
use strict;
use testapi;
use base "consoletest";
use utils 'zypper_call';
use power_action_utils 'power_action';

my $logs_dir = '/tmp/dracut-testsuite-logs';

sub testsuiteinstall {
    my $dracut_testsuite_repo = get_var('DRACUT_TESTSUITE_REPO', '');

    select_console 'root-console';

    my $from_repo = '';
    if ($dracut_testsuite_repo) {
        zypper_call "ar $dracut_testsuite_repo dracut-testrepo";
        zypper_call "--gpg-auto-import-keys ref dracut-testrepo";
        $from_repo = "--from dracut-testrepo";
    }
    zypper_call "in $from_repo dracut dracut-mkinitrd-deprecated dracut-qa-testsuite";
}

sub testsuiterun {
    my ($self, $test_name, $option) = @_;
    my $timeout = get_var('DRACUT_TEST_DEFAULT_TIMEOUT') || 300;
    
    select_console 'root-console';
    
    assert_script_run "mkdir -p $logs_dir";
    assert_script_run "cd /usr/lib/dracut/test/$test_name";
    assert_script_run "./test.sh --setup 2>&1 | tee $logs_dir/$test_name-setup.log", $timeout;
    # Check that dracut and grub2-mkconfig return 0
    assert_script_run "grep -q dracut-root-block-created $logs_dir/$test_name-setup.log";
    # Check dracut generation errors
    assert_script_run "! grep -e ERROR -e FAIL $logs_dir/$test_name-setup.log";

    power_action('reboot', textmode => 1);
    wait_still_screen(10, 60);
    assert_screen("linux-login", 600);
    enter_cmd "root";
    wait_still_screen 3;
    type_password;
    wait_still_screen 3;
    send_key 'ret';

    # Clean
    assert_script_run "cd /usr/lib/dracut/test/$test_name";
    assert_script_run './test.sh --clean';
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    assert_script_run("tar -czf dracut-testsuite-logs.tar.gz $logs_dir", 600);
    upload_logs('dracut-testsuite-logs.tar.gz');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
