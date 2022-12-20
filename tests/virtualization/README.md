# Virt-manager testing

Goal is to test all the **virt-manager** interface.
This test suite use an **openQA/virt-manager** wrapper (*lib/virtmanager.pm*).
You just need to define what you want to setup, action will be mostly done
using the wrapper. If you want to create a new test for **virt-manager** please try
to create a wrapper and add the intelligence in *lib/virtmanager.pm* as much as possible.

# Examples
See files in *tests* directory for example.

Declare a pool in *tests/virtualization/virtman_storage.pm*:
```js 
my $newpool = {
	"name" => "openQA_dir",
	"data" => {
	    "type" => "dir",
	    "target_path" => "/var/lib/libvirt/images/openQA_dir",
	},
    };
```

Declare a virtual net in *tests/virtualization/virtman_virtualnet*:
```js
    my $vnet = {
	"name" => "vnettest",
	"ipv4" => {
	    active => "true",
	    network => "192.168.100.0/24",
	    dhcpv4 => {
		active => "true",
		start => "192.168.100.12",
		end => "192.168.100.20",
	    },
	    staticrouteipv4 => {
		active => "false", # default
		tonet => "",
		viagw => "",
	    },
	},
	......
```


**Devel** is in progress, some choice has been made to speedup debugging (like restart
everything from a new window, to be sure we can validate a step, even if previous one was
broken).

# About this testsuite
* it closes all windows before doing anything else in **virt-manager**
  to avoid any trouble with "history" in the GUI which can lead to bad sequence.
  Of course this can be removed later if needed.
* **libvirt** is used to check the result of things done in **virt-manager**, so screen
  check is done using an xterm and some `virsh` command line.


# Current support
virtual network
-----------------
* create virtual network (all options supported)

Storage
-------
* create a new pool (all options supported), we do not support "gluster"
* create a new volume in a pool (all options, all formats)

Network interface
-----------------
* create a new interface (all options supported except bond one)
* delete an interface (Buggy now)

Preferences/View
----------------
* activate all preferences to enable all view 


# Launch a job for a worker

```js
/usr/share/openqa/script/client jobs post DISTRI=sle VERSION=12 ARCH=x86_64 \
	TEST=virtualization MACHINE=gui DESKTOP=icewm \
	HDDMODEL=virtio-blk-pci ISO=SLE-12-Server-DVD-x86_64-GM-DVD1.iso \
	QEMUCPUS=2 QEMURAM=2048 VIRTUALIZATION=1

/usr/share/openqa/script/client jobs post DISTRI=sle VERSION=12 ARCH=x86_64 \
        TEST=virtualization MACHINE=gui  \
        HDDMODEL=virtio-blk-pci ISO=SLE-12-SP1-Server-DVD-x86_64-Build2806-Media1.iso \
        QEMUCPUS=2 QEMURAM=2048 BETA=beta VIRTUALIZATION=1 STANDALONEVT=true

```

