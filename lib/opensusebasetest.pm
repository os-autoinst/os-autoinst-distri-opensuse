package opensusebasetest;
use base "basetest";

# Base class for all openSUSE tests

use testapi qw(send_key %cmd assert_screen check_screen check_var get_var type_password type_string);

# this needs to move to the distribution
sub init_cmd() {
    my ($self) = @_;

    ## keyboard cmd vars
    %testapi::cmd = qw(
      next alt-n
      xnext alt-n
      install alt-i
      update alt-u
      finish alt-f
      accept alt-a
      ok alt-o
      continue alt-o
      createpartsetup alt-c
      custompart alt-c
      addpart alt-d
      donotformat alt-d
      addraid alt-i
      add alt-a
      raid0 alt-0
      raid1 alt-1
      raid5 alt-5
      raid6 alt-6
      raid10 alt-i
      mountpoint alt-m
      filesystem alt-s
      acceptlicense alt-a
      instdetails alt-d
      rebootnow alt-n
      otherrootpw alt-s
      noautologin alt-a
      change alt-c
      software s
      package p
      bootloader b
    );

    if ( check_var('INSTLANG', "de_DE") ) {
        $testapi::cmd{"next"}            = "alt-w";
        $testapi::cmd{"createpartsetup"} = "alt-e";
        $testapi::cmd{"custompart"}      = "alt-b";
        $testapi::cmd{"addpart"}         = "alt-h";
        $testapi::cmd{"finish"}          = "alt-b";
        $testapi::cmd{"accept"}          = "alt-r";
        $testapi::cmd{"donotformat"}     = "alt-n";
        $testapi::cmd{"add"}             = "alt-h";

        #	$testapi::cmd{"raid6"}="alt-d"; 11.2 only
        $testapi::cmd{"raid10"}      = "alt-r";
        $testapi::cmd{"mountpoint"}  = "alt-e";
        $testapi::cmd{"rebootnow"}   = "alt-j";
        $testapi::cmd{"otherrootpw"} = "alt-e";
        $testapi::cmd{"change"}      = "alt-n";
        $testapi::cmd{"software"}    = "w";
    }
    if ( check_var('INSTLANG', "es_ES") ) {
        $testapi::cmd{"next"} = "alt-i";
    }
    if ( check_var('INSTLANG', "fr_FR") ) {
        $testapi::cmd{"next"} = "alt-s";
    }
    ## keyboard cmd vars end
}

# this needs to move to the distribution
sub x11_start_program($$$) {
    my ($self, $program, $timeout, $options) = @_;
    send_key "alt-f2";
    assert_screen("desktop-runner", $timeout);
    type_string $program;
    if ( $options->{terminal} ) { send_key "alt-t"; sleep 3; }
    send_key "ret", 1;
    # make sure desktop runner executed and closed when have had valid value
    # exec x11_start_program( $program, $timeout, { valid => 1 } );
    if ( $options->{valid} ) {
        # check 3 times
        foreach my $i ( 1..3 ) {
            last unless check_screen "desktop-runner-border", 2;
            send_key "ret", 1;
        }
    }
}

# this needs to move to the distribution
sub ensure_installed {
    my ($self, @pkglist) = @_;
    my $timeout;
    if ( $pkglist[-1] =~ /^[0-9]+$/ ) {
        $timeout = $pkglist[-1];
        pop @pkglist;
    }
    else {
        $timeout = 80;
    }

    testapi::x11_start_program("xterm");
    assert_screen('xterm-started');
    type_string("pkcon install @pkglist\n");
    my @tags = qw/Policykit Policykit-behind-window pkcon-proceed-prompt pkcon-succeeded/;
    while (1) {
        my $ret = assert_screen(\@tags, $timeout);
        if ( $ret->{needle}->has_tag('Policykit') ) {
            type_password;
            send_key( "ret", 1 );
            @tags = grep { $_ ne 'Policykit' } @tags;
            @tags = grep { $_ ne 'Policykit-behind-window' } @tags;
            next;
        }
        if ( $ret->{needle}->has_tag('Policykit-behind-window') ) {
            send_key("alt-tab");
            sleep 3;
            next;
        }
        if ( $ret->{needle}->has_tag('pkcon-proceed-prompt') ) {
            send_key("y");
            send_key("ret");
            @tags = grep { $_ ne 'pkcon-proceed-prompt' } @tags;
            next;
        }
        if ( $ret->{needle}->has_tag('pkcon-succeeded') ) {
            send_key("alt-f4");    # close xterm
            return;
        }
    }

    if ($password) { type_password; send_key("ret", 1); }
    wait_still_screen( 7, 90 );    # wait for install
}

sub clear_and_verify_console {
    my ($self) = @_;

    send_key "ctrl-l";
    assert_screen('cleared-console');

}

sub pass_disk_encrypt_check {
    my ($self) = @_;

    assert_screen("encrypted-disk-password-prompt");
    type_password();    # enter PW at boot
    send_key "ret";
}

sub post_run_hook {
    my ($self) = @_;
    # overloaded in x11 and console
}

1;
# vim: set sw=4 et:
