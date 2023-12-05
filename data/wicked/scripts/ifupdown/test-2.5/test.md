VLAN on Team of physical interfaces

---

### tree:
```
    eth1,eth2   -m->    team0   <-l-    team0.11
```

---

### ifup:

#### wicked ifup eth1

    - setup    eth1                requested
      - setup    team0             required master reference
    - skip     team0.11            unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    eth1                requested
      - setup    team0             required master reference
        - setup    team0.11        via links trigger
    - skip     eth2                unrequested / not required by setup interfaces

#### wicked ifup eth2

    - setup    eth2                requested
      - setup    team0             required master reference
    - skip     team0.11            unrequested / not required by setup interfaces
    - skip     eth1                unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    eth2                requested
      - setup    team0             required master reference
        - setup    team0.11        via links trigger
    - skip     eth1                unrequested / not required by setup interfaces

#### wicked ifup team0

    - setup    team0               requested
      - setup    eth1              via ports trigger
      - setup    eth2              via ports trigger
    - skip     team0.11            unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    team0               requested
      - setup    eth1              via ports trigger
      - setup    eth2              via ports trigger
      - setup    team0.11          via links trigger

    trigger: links=enabled, ports=disabled

    - setup    team0               requested
      - setup    team0.11          via links trigger
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces

    trigger: ports=disabled

    - setup    team0               requested
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces
    - skip     team0.11            unrequested / not required by setup interfaces

#### wicked ifup team0.11

    - setup    team0.11            requested
      - setup    team0             required lower reference
        - setup    eth1            via ports trigger
        - setup    eth2            via ports trigger

    trigger: ports=disabled

    - setup    team0.11            requested
      - setup    team0             required lower reference
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces

---

### ifdown:

#### wicked ifdown eth1

    - shutdown eth1                requested
    - skip     eth2                unrequested / no reference to shutdown interfaces
    - skip     team0               unrequested / no reference to shutdown interfaces
    - skip     team0.11            unrequested / no reference to shutdown interfaces

#### wicked ifdown eth2

    - shutdown eth2                requested
    - skip     eth1                unrequested / no reference to shutdown interfaces
    - skip     team0               unrequested / no reference to shutdown interfaces
    - skip     team0.11            unrequested / no reference to shutdown interfaces

#### wicked ifdown team0

    - shutdown team0               requested
      - shutdown team0.11          depends on lower shutdown
      - shutdown eth1              depends on master shutdown
      - shutdown eth2              depends on master shutdown

#### wicked ifdown team0.11

    - shutdown team0.11            requested
    - skip     team0               unrequested / no reference to shutdown interfaces
    - skip     eth1                unrequested / no reference to shutdown interfaces
    - skip     eth2                unrequested / no reference to shutdown interfaces

