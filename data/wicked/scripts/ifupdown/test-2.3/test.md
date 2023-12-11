VLANs on Bond of physical interfaces

---

### tree:
```
    eth1,eth2   -m->    bond0   <-l-    bond0.11
                                <-l-    bond0.12
```

---

### ifup:

#### wicked ifup eth1

    - setup    eth1                requested
      - setup    bond0             required master reference
    - skip     bond0.11            unrequested / not required by setup interfaces
    - skip     bond0.12            unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    eth1                requested
      - setup    bond0             required master reference
        - setup    bond0.11        via links trigger
        - setup    bond0.12        via links trigger
    - skip     eth2                unrequested / not required by setup interfaces

#### wicked ifup eth2

    - setup    eth2                requested
      - setup    bond0             required master reference
    - skip     bond0.11            unrequested / not required by setup interfaces
    - skip     bond0.12            unrequested / not required by setup interfaces
    - skip     eth1                unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    eth2                requested
      - setup    bond0             required master reference
        - setup    bond0.11        via links trigger
        - setup    bond0.12        via links trigger
    - skip     eth1                unrequested / not required by setup interfaces

#### wicked ifup bond0

    - setup    bond0               requested
      - setup    eth1              via ports trigger
      - setup    eth2              via ports trigger
    - skip     bond0.11            unrequested / not required by setup interfaces
    - skip     bond0.12            unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    bond0               requested
      - setup    eth1              via ports trigger
      - setup    eth2              via ports trigger
      - setup    bond0.11          via links trigger
      - setup    bond0.12          via links trigger

    trigger: links=enabled, ports=disabled

    - setup    bond0               requested
      - setup    bond0.11          via links trigger
      - setup    bond0.12          via links trigger
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces

    trigger: ports=disabled

    - setup    bond0               requested
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces
    - skip     bond0.11            unrequested / not required by setup interfaces
    - skip     bond0.12            unrequested / not required by setup interfaces

#### wicked ifup bond0.11

    - setup    bond0.11            requested
      - setup    bond0             required lower reference
        - setup    eth1            via ports trigger
        - setup    eth2            via ports trigger
    - skip     bond0.12            unrequested / not required by setup interfaces

    trigger: ports=disabled

    - setup    bond0.11            requested
      - setup    bond0             required lower reference
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces
    - skip     bond0.12            unrequested / not required by setup interfaces

#### wicked ifup bond0.12

    - setup    bond0.12            requested
      - setup    bond0             required lower reference
        - setup    eth1            via ports trigger
        - setup    eth2            via ports trigger
    - skip     bond0.11            unrequested / not required by setup interfaces

    trigger: ports=disabled

    - setup    bond0.12            requested
      - setup    bond0             required lower reference
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces
    - skip     bond0.11            unrequested / not required by setup interfaces

---

### ifdown:

#### wicked ifdown eth1

    - shutdown eth1                requested
    - skip     eth2                unrequested / no reference to shutdown interfaces
    - skip     bond0               unrequested / no reference to shutdown interfaces
    - skip     bond0.11            unrequested / no reference to shutdown interfaces
    - skip     bond0.12            unrequested / no reference to shutdown interfaces

#### wicked ifdown eth2

    - shutdown eth2                requested
    - skip     eth1                unrequested / no reference to shutdown interfaces
    - skip     bond0               unrequested / no reference to shutdown interfaces
    - skip     bond0.11            unrequested / no reference to shutdown interfaces
    - skip     bond0.12            unrequested / no reference to shutdown interfaces

#### wicked ifdown bond0

    - shutdown bond0               requested
      - shutdown bond0.11          depends on lower shutdown
      - shutdown bond0.12          depends on lower shutdown
      - shutdown eth1              depends on master shutdown
      - shutdown eth2              depends on master shutdown

#### wicked ifdown bond0.11

    - shutdown bond0.11            requested
    - skip     bond0               unrequested / no reference to shutdown interfaces
    - skip     eth1                unrequested / no reference to shutdown interfaces
    - skip     eth2                unrequested / no reference to shutdown interfaces
    - skip     bond0.12            unrequested / no reference to shutdown interfaces

#### wicked ifdown bond0.12

    - shutdown bond0.12            requested
    - skip     bond0               unrequested / no reference to shutdown interfaces
    - skip     eth1                unrequested / no reference to shutdown interfaces
    - skip     eth2                unrequested / no reference to shutdown interfaces
    - skip     bond0.11            unrequested / no reference to shutdown interfaces

