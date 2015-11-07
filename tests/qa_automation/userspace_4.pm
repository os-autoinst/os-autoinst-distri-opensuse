use base "qa_run";
use testapi;

sub create_qaset_config() {
    # Add test list 4 for userspace
    assert_script_run "echo 'SQ_TEST_RUN_LIST=(\n _reboot_off\n fetchmail\n php5\n systemd\n)' > /root/qaset/config";
}

sub test_suite() {
    return 'regression';
}

sub junit_type() {
    return 'user_regression';
}

1;

