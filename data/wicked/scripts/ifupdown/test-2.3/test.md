VLAN on Bond of physical interfaces

---

### tree:
```
    eth1,eth2   -m->    bond0   <-l-    bond0.11
```

---

### ifup:

#### wicked ifup eth1

    - setup    eth1                requested
      - setup    bond0             required master reference
    - skip     bond0.11            unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces

    options: --links

    - setup    eth1                requested
      - setup    bond0             required master reference
        - setup    bond0.11        via --links
    - skip     eth2                unrequested / not required by setup interfaces

#### wicked ifup eth2

    - setup    eth2                requested
      - setup    bond0             required master reference
    - skip     bond0.11            unrequested / not required by setup interfaces
    - skip     eth1                unrequested / not required by setup interfaces

    options: --links

    - setup    eth2                requested
      - setup    bond0             required master reference
        - setup    bond0.11        via --links
    - skip     eth1                unrequested / not required by setup interfaces

#### wicked ifup bond0

    - setup    bond0               requested
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces
    - skip     bond0.11            unrequested / not required by setup interfaces

    options: --ports

    - setup    bond0               requested
      - setup    eth1              via --ports
      - setup    eth2              via --ports
    - skip     bond0.11            unrequested / not required by setup interfaces

    options: --links

    - setup    bond0               requested
      - setup    bond0.11          via --links
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces

    options: --ports, --links

    - setup    bond0               requested
      - setup    eth1              via --ports
      - setup    eth2              via --ports
      - setup    bond0.11          via --links

#### wicked ifup bond0.11

    - setup    bond0.11            requested
      - setup    bond0             required lower reference
    - skip     eth1                unrequested / not required by setup interfaces
    - skip     eth2                unrequested / not required by setup interfaces

    options: --ports

    - setup    bond0.11            requested
      - setup    bond0             required lower reference
        - setup    eth1            via --ports
        - setup    eth2            via --ports

---

### ifdown:

#### wicked ifdown eth1

    - shutdown eth1                requested
    - skip     eth2                unrequested / no reference to shutdown interfaces
    - skip     bond0               unrequested / no reference to shutdown interfaces
    - skip     bond0.11            unrequested / no reference to shutdown interfaces

#### wicked ifdown eth2

    - shutdown eth2                requested
    - skip     eth1                unrequested / no reference to shutdown interfaces
    - skip     bond0               unrequested / no reference to shutdown interfaces
    - skip     bond0.11            unrequested / no reference to shutdown interfaces

#### wicked ifdown bond0

    - shutdown bond0               requested
      - shutdown bond0.11          depends on lower shutdown
      - shutdown eth1              depends on master shutdown
      - shutdown eth2              depends on master shutdown

#### wicked ifdown bond0.11

    - shutdown bond0.11            requested
    - skip     bond0               unrequested / no reference to shutdown interfaces
    - skip     eth1                unrequested / no reference to shutdown interfaces
    - skip     eth2                unrequested / no reference to shutdown interfaces

