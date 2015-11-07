use base "qa_run";
use testapi;

sub create_qaset_config() {
    # Add test list 1 for userspace
    assert_script_run "echo 'SQ_TEST_RUN_LIST=(\n _reboot_off\n apache\n apparmor\n apparmor_profiles\n bind\n bzip2\n)' > /root/qaset/config";
}

sub test_suite() {
    return 'regression';
}

sub junit_type() {
    return 'user_regression';
}

1;

