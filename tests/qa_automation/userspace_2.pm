use base "qa_run";
use testapi;

sub test_run_list() {
    return qw(_reboot_off postfix sharutils coreutils cpio cracklib findutils gzip indent net_snmp);
}

sub test_suite() {
    return 'regression';
}

sub junit_type() {
    return 'user_regression';
}

1;

