use base "y2logsstep";
use strict;
use testapi;

sub run() {
	my $self = shift;

    assert_screen 'inst-overview', 5;
    send_key $cmd{change};
    send_key 'p'; # paritioning
    
    # Basic little hop through to give it a default scenario to edit
    assert_screen 'preparing-disk', 5;
    send_key 'alt-1';
    send_key $cmd{"next"};
    send_key $cmd{"next"};

    assert_screen 'inst-overview', 5;
    send_key $cmd{change};
    send_key 'p'; # paritioning
    
    assert_screen 'preparing-disk', 5;
    send_key 'alt-c';
    send_key $cmd{"next"};

    assert_screen 'expert-partitioning', 5;
    
	send_key 'down';
		# TODO throw some asserts in :)
    send_key 'down';
    send_key 'right';
    send_key 'down'; #should select first disk'
    send_key 'right';
    send_key 'down'; #should be swap
    send_key 'down'; #should be root partition
    
    send_key 'alt-s'; #goto filesystem list
    send_key ' '; #open filesystem list
    send_key 'home'; #go to top of the list
    
    my $wfs = get_var('FILESYSTEM');
    
    key_round "filesystem-$wfs", 'down';
	send_key 'ret';
	send_key 'alt+f';
	send_key 'alt+a';
    
}

1;
# vim: set sw=4 et:
