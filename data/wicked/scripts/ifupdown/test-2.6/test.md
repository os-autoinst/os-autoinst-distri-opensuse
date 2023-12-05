OVS VLAN 1 Bridge with Parent-Bridge on physical interface

- ovsbr0 is a bridge with physical port eth1 (untagged eth1 traffic)
- ovsbr1 refers to ovsbr0 as parent with vlan 1 (tagged eth1 traffic)

---

### tree:
```
    eth1   -m->    ovsbr0   <-l-    ovsbr1
```

---

### ifup:

#### wicked ifup eth1

    - setup    eth1                requested
      - setup    ovsbr0            required master reference
    - skip     ovsbr1              unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    eth1                requested
      - setup    ovsbr0            required master reference
        - setup    ovsbr1          via links trigger

#### wicked ifup ovsbr0

    - setup    ovsbr0              requested
      - setup    eth1              via ports trigger
    - skip     ovsbr1              unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    ovsbr0              requested
      - setup    eth1              via ports trigger
      - setup    ovsbr1            via links trigger

    trigger: links=enabled, ports=disabled

    - setup    ovsbr0              requested
      - setup    ovsbr1            via links trigger
    - skip     eth1                unrequested / not required by setup interfaces

    trigger: ports=disabled

    - setup    ovsbr0              requested
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     ovsbr1              unrequested / not required by setup interfaces

#### wicked ifup ovsbr1

    - setup    ovsbr1              requested
      - setup    ovsbr0            required lower reference
        - setup    eth1            via ports trigger

    trigger: ports=disabled

    - setup    ovsbr1              requested
      - setup    ovsbr0            required lower reference
    - skip     eth1                unrequested / not required by setup interfaces

---

### ifdown:

#### wicked ifdown eth1

    - shutdown eth1                requested
    - skip     ovsbr0              unrequested / no reference to shutdown interfaces
    - skip     ovsbr1              unrequested / no reference to shutdown interfaces

#### wicked ifdown ovsbr0

    - shutdown ovsbr0              requested
      - shutdown ovsbr1            depends on lower shutdown
      - shutdown eth1              depends on master shutdown

#### wicked ifdown ovsbr1

    - shutdown ovsbr1              requested
    - skip     ovsbr0              unrequested / no reference to shutdown interfaces
    - skip     eth1                unrequested / no reference to shutdown interfaces

