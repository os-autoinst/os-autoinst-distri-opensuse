use base "qa_run";
use testapi;

sub create_qaset_config() {
    # nothing by default
}

sub junit_type() {
    return 'stress_validation';
}

sub test_suite() {
    return 'acceptance';
}

1;

