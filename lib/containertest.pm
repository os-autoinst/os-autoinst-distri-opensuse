package containertest;
use base 'consoletest';
use strict;
use testapi;

use Exporter 'import';
our @EXPORT_OK = qw($runc setup_container_in_background runc_test);

our $runc = '/usr/sbin/runc';

sub setup_container_in_background {
    script_run('cd bundle && cp config.json config.json.backup');
    assert_script_run("sed -i -e '/\"terminal\":/ s/: .*/: false,/' config.json");
    assert_script_run("sed -i -e 's/\"\\/bin\\/bash\"/\"echo\", \"42km\"/' config.json");
}

sub runc_test {
    assert_script_run("$runc run marathon | grep 42km");
    # Restore the default configuration
    assert_script_run('mv config.json.backup config.json');
    assert_script_run("sed -i -e '/\"terminal\":/ s/: .*/: false,/' config.json");
    assert_script_run("sed -i -e 's/\"\\/bin\\/bash\"/\"sleep\", \"120\"/' config.json");

    # Container Lifecycle
    record_info 'Test #3', 'Test: Create a container';
    assert_script_run("$runc create life");
    assert_script_run("$runc state life | grep status | grep created");
    record_info 'Test #4', 'Test: List containers';
    assert_script_run("$runc list | grep life");
    record_info 'Test #5', 'Test: Start a container';
    assert_script_run("$runc start life");
    assert_script_run("$runc state life | grep running");
    record_info 'Test #6', 'Test: Pause a container';
    assert_script_run("$runc pause life");
    assert_script_run("$runc state life | grep paused");
    record_info 'Test #7', 'Test: Resume a container';
    assert_script_run("$runc resume life");
    assert_script_run("$runc state life | grep running");
}

1;

