use base "installbasetest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    my $zypper_continue = qr/^Continue\? \[y/m;
    my $zypper_conflict = qr/^Choose from above solutions by number[\s\S,]* \[1/m;
    my $zypper_error = qr/^Abort, retry, ignore\? \[a/m;
    my $zypper_fileconflict = qr/^File conflicts .*^Continue\? \[y/ms;
    my $zypper_finish = qr/^There are some running programs that might use files|^ZYPPER-DONE/m;

    # zypper patch and fully update the system
    script_run ("(zypper -n patch;echo ZYPPER-DONE) | tee /dev/$serialdev");
    wait_serial $zypper_finish, 100;

    script_run ("(zypper up --auto-agree-with-licenses;echo ZYPPER-DONE) | tee /dev/$serialdev");
    my $out = wait_serial([$zypper_continue, $zypper_conflict, $zypper_error, $zypper_fileconflict, $zypper_finish], 5000);
    while ($out) {
       if ($out =~ $zypper_conflict || $out =~ $zypper_error || $out =~ $zypper_fileconflict) {
            $self->result('fail');
            save_screenshot;
            return;
       }
       elsif ($out =~ $zypper_continue) {
           send_key "y", 1;
           send_key "ret";
       }
       elsif ($out =~ $zypper_finish) {
           last;    
       }
       $out = wait_serial([$zypper_continue, $zypper_conflict, $zypper_error, $zypper_fileconflict, $zypper_finish], 5000);
    }
}

sub test_flags() {
    return {'fatal' => 1};
}

1;
# vim: set sw=4 et:
