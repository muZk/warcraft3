# Proj

A library to manage projectile movement in warcraft 3.

Library code looks uggly, API is awful, but with this you can write movement-base abilities with no effort. Also, isn't documented yet but provides:

- Parabolic movement like war3 projectile engine ("Arc" projectiles).
- Homing and grounds projectiles.
- Safe movement (units cannot go outside map).
- You can add callbacks to a instance of projectile:
	- On every tick
		- Common use case: add effects when the projectile is traveling
	- When a unit colides with the projectile (AoE collision is customizable)
		- Common use case: damage a enemy unit
	- When the projectile hits target location
		- Common use case: remove units or add effects
	- Enum units in certain AoE when unit hits target location.


# Usage (TODO)

# Install (TODO)