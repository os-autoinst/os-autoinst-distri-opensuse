use base "installbasetest";
use testapi;
use autotest;

sub run() {
    assert_screen 'linux-login', 200;
    type_string "init 0\n"; #shutdown VM
    type_string "exit\n";
    check_screen 'proxy-terminal',30; #should be assert
    send_key 'ctrl-l';
    sleep 60; #Give it 60 seconds to shut down the VM
    use bmwqemu;
    bmwqemu::make_snapshot('ha-sle11_ha_preparation');
}

1;
