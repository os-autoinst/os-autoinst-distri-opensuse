use base "y2logsstep";
use strict;
use testapi;

sub run() {
	my $self = shift;

    assert_screen 'inst-overview', 10;
    send_key $cmd{change};
    send_key 'p'; # partitioning
    
    # Basic little hop through to give it a default scenario to edit
    assert_screen 'preparing-disk', 5;
    send_key 'alt-1';
    send_key $cmd{"next"};
    assert_screen 'preparing-disk-installing', 5;
    send_key 'alt-u'; #to use btrfs
    send_key $cmd{"next"};

	if ( !check_var( "FILESYSTEM", "btrfs" ) ) {
		
		assert_screen 'inst-overview', 10;
		send_key $cmd{change};
		send_key 'p'; # partitioning
		assert_screen 'preparing-disk', 5;
		send_key 'alt-c';
		send_key $cmd{"next"};
		assert_screen 'expert-partitioning', 5;
		send_key 'down';
		send_key 'down';
		send_key 'right';
		send_key 'down'; #should select first disk'
		send_key 'right';
		send_key 'down'; #should be boot
		send_key 'down'; #should be swap
		send_key 'down'; #should be root partition
		assert_screen 'on-root-partition', 5;
		send_key 'alt-e'; #got to actually edit
		assert_screen 'editing-root-partition', 5;
		send_key 'alt-s'; #goto filesystem list
		send_key ' '; #open filesystem list
		send_key 'home'; #go to top of the list
		
		my $counter = 20;
		while (1) {
			my $ret = wait_screen_change {
				send_key 'down';
			};
			# down didn't change the screen, so exit here
			die "looping for too long/filesystem not found" if (!$ret || $counter-- == 0);
			
			my $fs = get_var('FILESYSTEM');
		
			if (check_screen("filesystem-$fs", 1)) {
				send_key 'ret';
				send_key 'alt-f';
				send_key 'alt-a';
				assert_screen('inst-overview', 10);
				last;
			}
		}
	}
}

1;
# vim: set sw=4 et:
