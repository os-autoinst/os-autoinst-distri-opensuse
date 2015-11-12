use base "qa_run";
use testapi;

sub test_run_list() {
    return qw(_reboot_off process_stress);
}

sub junit_type() {
    return 'stress_validation';
}

sub test_suite() {
    return 'acceptance';
}

1;

