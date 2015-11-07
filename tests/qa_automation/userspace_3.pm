use base "qa_run";
use testapi;

sub create_qaset_config() {
    # Add test list 3 for userspace
    assert_script_run "echo 'SQ_TEST_RUN_LIST=(\n _reboot_off\n nfs\n nfs_v4\n openssh\n openssl\n)' > /root/qaset/config";
}

sub test_suite() {
    return 'regression';
}

sub junit_type() {
    return 'user_regression';
}

1;

