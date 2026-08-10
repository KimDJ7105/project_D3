extends Node
## Autoload singleton. Tracks relationship values between the player and
## NPCs/factions, and exposes lookups other systems (dialogue, dungeon events,
## combat) query to react to relationship state.
##
## Data structure (individual vs individual+faction) is not decided yet —
## see docs/01_relationship_system.md before implementing.
