use base "qa_run";
use testapi;

sub test_run_list() {
    return qw(_reboot_off apache apparmor apparmor_profiles bind bzip2);
}

sub test_suite() {
    return 'regression';
}

sub junit_type() {
    return 'user_regression';
}

1;

