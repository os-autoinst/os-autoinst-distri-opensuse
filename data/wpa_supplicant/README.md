# wpa_supplicant test for openQA

Tests the functionality of `wpa_supplicant` by creating a virtual wifi network using the [mac80211_hwsim](https://wireless.wiki.kernel.org/en/users/Drivers/mac80211_hwsim) kernel module and network namespace separation.

This archive works also as a standalone test for ``wpa_supplicant`

## Usage

    Usage:
    ./wpa_supplicant_test.sh

If the test terminates with the following lines, you're good

    [...]
    PING 192.168.202.1 (192.168.202.1) 56(84) bytes of data.
    64 bytes from 192.168.202.1: icmp_seq=1 ttl=64 time=0.162 ms
    64 bytes from 192.168.202.1: icmp_seq=2 ttl=64 time=0.359 ms
    64 bytes from 192.168.202.1: icmp_seq=3 ttl=64 time=0.287 ms
    64 bytes from 192.168.202.1: icmp_seq=4 ttl=64 time=0.270 ms
    
    --- 192.168.202.1 ping statistics ---
    4 packets transmitted, 4 received, 0% packet loss, time 3051ms                                                             
    rtt min/avg/max/mdev = 0.162/0.269/0.359/0.072 ms
    
    
    
    [Info] ignore the 'rfkill: Cannot get wiphy information' warnings                                                          
    
    
    [ OK ] wpa_supplicant regression test completed successfully

The last line says, everything went fine.

## Requirements

    zypper install wpa_supplicant hostapd iw dnsmasq unzip

# Copyright 

Copyright © 2020 SUSE LLC

Copying and distribution of this file, with or without modification,
are permitted in any medium without royalty provided the copyright
notice and this notice are preserved.  This file is offered as-is,
without any warranty.

## Author

Felix Niederwanger <felix.niederwanger@suse.de>

