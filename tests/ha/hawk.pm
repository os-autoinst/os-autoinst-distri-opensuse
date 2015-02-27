use base "installbasetest";
use testapi;
use autotest;

sub run() {
    type_string "exit\n";
    type_string "firefox https://10.0.2.16:7630/\n";
    assert_and_click 'firefox-understand-risks';
    assert_and_click 'firefox-add-exception';
    assert_and_click 'firefox-confirm-exception';
    assert_screen 'hawk-login';
    assert_and_click 'hawk-username';
    type_string 'hacluster';
    send_key 'tab';
    type_string "linux\n";
    assert_screen 'hawk-dashboard';
}

1;
