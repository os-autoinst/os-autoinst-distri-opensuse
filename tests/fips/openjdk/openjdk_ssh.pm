# SUSE's openjdk fips tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openjdk expect
#
# Summary: FIPS: openjdk
#          Jira feature: SLE-21206
#          FIPS 140-3: make OpenJDK be able to use the NSS certified crypto
#          Run Java SSH / Client http://www.jcraft.com/jsch/
# Tags: poo#112034
# Maintainer: Yutao Wang <yuwang@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = @_;
    select_console('x11');

    # Start an xterm
    x11_start_program("xterm");
    # Wait before typing to avoid typos
    wait_still_screen(5);

    my $JSCH_JAR = get_var("JSCH_JAR", "https://gitlab.suse.de/qe-security/testing/-/raw/main/data/openjdk/jsch-0.1.55.jar");
    assert_script_run("wget --quiet --no-check-certificate $JSCH_JAR");
    assert_script_run("chmod 777 jsch-0.1.55.jar");

    my $TEST_JAVA = get_var("TEST_JAVA", "https://gitlab.suse.de/qe-security/testing/-/raw/main/data/openjdk/Shell.java");
    assert_script_run("wget --quiet --no-check-certificate $TEST_JAVA");
    assert_script_run("chmod 777 Shell.java");

    assert_script_run("javac -cp jsch-0.1.55.jar:. Shell.java");
    script_run("java -cp jsch-0.1.55.jar:. Shell", timeout => 0);
    assert_screen "openjdk-hostname";
    for (1 .. 30) { send_key "backspace"; }
    type_string get_var("OPENJDK_HN", 'bernhard@localhost');
    save_screenshot;
    send_key 'ret';
    wait_still_screen 3;
    send_key 'ret';
    save_screenshot;
    wait_still_screen 3;
    send_key 'ret' if (check_screen("auth-key-connect", 10));
    wait_still_screen 3;
    record_info("FAIL", "java.security.ProviderException: Could not derive key", result => 'fail') if (check_screen("shell-not-derive-key", 10));
    send_key 'ret';
    save_screenshot;
    wait_still_screen 3;
    send_key 'alt-f4';
}

1;
