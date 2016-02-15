use base "qa_run";
use testapi;

sub test_run_list() {
    return qw(_reboot_off memtester);
}

sub test_suite() {
    return 'kernel';
}

sub junit_type() {
    return 'kernel_regression';
}

1;
