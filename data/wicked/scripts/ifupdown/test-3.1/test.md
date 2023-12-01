Bridges on Bond interface and it's VLAN

---

### tree:
```
    eth1,eth2   -m->    bond0            -m->   br10
                        ^
                        +-l-    bond0.11 -m->   br11
```

---

### ifup:

#### wicked ifup eth1

    - setup    eth1                requested
      - setup    bond0             required master reference
        - setup    br10            required master reference
    - skip     eth2                unrequested / not required by setup interfaces
    - skip     bond0.11            unrequested / not required by setup interfaces
    - skip     br11                unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    eth1                requested
      - setup    bond0             required master reference
        - setup    br10            required master reference
        - setup    bond0.11        via links trigger
          - setup    br11          required master reference
    - skip     eth2                unrequested / not required by setup interfaces

#### wicked ifup eth2

    - setup    eth2                requested
      - setup    bond0             required master reference
        - setup    br10            required master reference
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     bond0.11            unrequested / not required by setup interfaces
    - skip     br11                unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    eth2                requested
      - setup    bond0             required master reference
        - setup    br10            required master reference
        - setup    bond0.11        via links trigger
          - setup    br11          required master reference
    - skip     eth1                unrequested / not required by setup interfaces

#### wicked ifup bond0

    - setup    bond0               requested
      - setup    eth1              via ports trigger
      - setup    eth2              via ports trigger
      - setup    br10              required master reference
    - skip     bond0.11            unrequested / not required by setup interfaces
    - skip     br11                unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    bond0               requested
      - setup    eth1              via ports trigger
      - setup    eth2              via ports trigger
      - setup    br10              required master reference
      - setup    bond0.11          via links trigger
        - setup    br11            required master reference

    trigger: ports=disabled

    - setup    bond0               requested
      - setup    br10              required master reference
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces
    - skip     bond0.11            unrequested / not required by setup interfaces
    - skip     br11                unrequested / not required by setup interfaces

    trigger: ports=disabled, links=enabled

    - setup    bond0               requested
      - setup    br10              required master reference
      - setup    bond0.11          via links trigger
        - setup    br11            required master reference
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces

#### wicked ifup bond0.11

    - setup    bond0.11            requested
      - setup    bond0             required lower reference
        - setup    br10            required master reference
        - setup    br11            required master reference
      - setup    eth1              via ports trigger
      - setup    eth2              via ports trigger

    trigger: ports=disabled

    - setup    bond0.11            requested
      - setup    bond0             required lower reference
      - setup    br10              required master reference
      - setup    br11              required master reference
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces

#### wicked ifup br10

    - setup    br10                requested
      - setup    bond0             via ports trigger
        - setup    eth1            via ports trigger
        - setup    eth2            via ports trigger
    - skip     bond0.11            unrequested / not required by setup interfaces
    - skip     br11                unrequested / not required by setup interfaces

    trigger: ports=disabled

    - setup    br10                requested
    - skip     bond0               unrequested / not required by setup interfaces
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces
    - skip     bond0.11            unrequested / not required by setup interfaces
    - skip     br11                unrequested / not required by setup interfaces

#### wicked ifup br11

    - setup    br11                requested
      - setup    bond0.11          via ports trigger
        - setup    bond0           required lower reference
          - setup    eth1          via ports trigger
          - setup    eth2          via ports trigger
          - setup    br10          required master reference

    trigger: ports=disabled

    - setup    br11                requested
    - skip     bond0.11            unrequested / not required by setup interfaces
    - skip     bond0               unrequested / not required by setup interfaces
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces
    - skip     br10                unrequested / not required by setup interfaces

---

### ifdown:

#### wicked ifdown eth1

    - shutdown eth1                requested
    - skip     eth2                unrequested / no reference to shutdown interfaces
    - skip     bond0               unrequested / no reference to shutdown interfaces
    - skip     bond0.11            unrequested / no reference to shutdown interfaces
    - skip     br10                unrequested / no reference to shutdown interfaces
    - skip     br11                unrequested / no reference to shutdown interfaces

#### wicked ifdown eth2

    - shutdown eth2                requested
    - skip     eth1                unrequested / no reference to shutdown interfaces
    - skip     bond0               unrequested / no reference to shutdown interfaces
    - skip     bond0.11            unrequested / no reference to shutdown interfaces
    - skip     br10                unrequested / no reference to shutdown interfaces
    - skip     br11                unrequested / no reference to shutdown interfaces

#### wicked ifdown bond0

    - shutdown bond0               requested
      - shutdown eth1              depends on master shutdown
      - shutdown eth2              depends on master shutdown
      - shutdown bond0.11          depends on lower shutdown
    - skip     br10                unrequested / no reference to shutdown interfaces
    - skip     br11                unrequested / no reference to shutdown interfaces

#### wicked ifdown bond0.11

    - shutdown bond0.11            requested
    - skip     bond0               unrequested / no reference to shutdown interfaces
    - skip     eth1                unrequested / no reference to shutdown interfaces
    - skip     eth2                unrequested / no reference to shutdown interfaces
    - skip     br10                unrequested / no reference to shutdown interfaces
    - skip     br11                unrequested / no reference to shutdown interfaces

#### wicked ifdown br10

    - shutdown br10                requested
      - shutdown bond0             depends on master shutdown
        - shutdown bond0.11        depends on lower shutdown
        - shutdown eth1            depends on master shutdown
        - shutdown eth2            depends on master shutdown
    - skip     br11                unrequested / no reference to shutdown interfaces
 
#### wicked ifdown br11

    - shutdown br11                requested
      - shutdown bond0.11          depends on master shutdown
    - skip     bond0               unrequested / no reference to shutdown interfaces
    - skip     eth1                unrequested / no reference to shutdown interfaces
    - skip     eth1                unrequested / no reference to shutdown interfaces
    - skip     br10                unrequested / no reference to shutdown interfaces

