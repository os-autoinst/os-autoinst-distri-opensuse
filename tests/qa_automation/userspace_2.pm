use base "qa_run";
use testapi;

sub create_qaset_config() {
    # Add test list 2 for userspace
    assert_script_run "echo 'SQ_TEST_RUN_LIST=(\n _reboot_off\n postfix\n sharutils\n coreutils\n cpio\n cracklib\n findutils\n gzip\n indent\n net_snmp\n)' > /root/qaset/config";
}

sub test_suite() {
    return 'regression';
}

sub junit_type() {
    return 'user_regression';
}

1;

