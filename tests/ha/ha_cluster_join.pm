use base "installbasetest";
use testapi;
use autotest;

sub run() {
}

sub test_flags {
    return { milestone => 1, fatal => 1, important => 1 };
}

1;
