# CorsixTH #826 glossary

This glossary is a reading aid for the #826 patch. It does not change the code or define new game behaviour.

Review branch: `review/issue-826-split`

A useful mental model for the whole patch is:

> **Before placement:** remember what is connected.  
> **Pretend the object/room has been placed:** see what connectivity changed.  
> **Only if something was newly cut off:** check whether anything important was inside that newly cut-off area.

## Main terms

### candidate
The object, room wall, or door that is **currently being tested for placement**.

It is not necessarily placed yet. The code temporarily asks: “What would the map look like if we put this here?”

**Example:** while moving a plant with the mouse, that plant at the currently highlighted tile is the candidate.

### candidate tile(s)
Specific tile(s) belonging to the candidate that must themselves remain reachable.

This is most visible for objects such as a Reception Desk, where the important tiles are its use positions rather than only the tile occupied by the desk graphic.

**Example:** the tile where the receptionist stands to use the desk can be a candidate tile.

### protected endpoint / protected tile
A location that the placement is **not allowed to newly cut off** from the hospital's usable entrance/spawn network.

Current examples include:
- room entrances / doors,
- Reception Desk use positions,
- humanoids, when the relevant check is enabled.

“Endpoint” just means “a location we care about being able to reach.” It does not mean an endpoint in a networking/API sense.

**Example:** if placing the fourth plant creates a sealed pocket containing a room door, that door is a protected endpoint.

### ingress
A tile that acts as an **outside access / spawn anchor** for the hospital connectivity check.

For this patch, ingress tiles are the stored normal spawn points plus the heliport spawn position when one exists.

A simple way to read it is: **“a place the hospital must remain connected to.”**

**Example:** if patients enter from two map spawn points, those two points are ingress tiles.

### topology
The **shape of walkable connectivity** on the map: which tiles can reach which other tiles through valid paths.

It is about connections, not graphics.

**Example:** adding a plant can leave all the same floor tiles visible but change the topology because one corridor route is no longer traversable.

### candidate topology / prospective topology
The temporary connectivity state **as if the candidate had already been placed**.

The code applies the candidate's pathfinding changes, runs the checks, then restores the original map state.

**Example:** before actually placing a plant, the code temporarily marks the relevant travel directions as blocked and asks whether the hospital would still be connected.

### baseline
A snapshot/reference of the **pre-candidate state** used for comparison.

In plain language: “remember how things worked before we pretend to place this object.”

The patch uses more than one baseline because it deliberately postpones expensive checks until they are actually needed.

### ingress baseline / impact baseline
The first, cheap baseline captured before the candidate is applied.

It records enough information to answer:
1. which ingress points were connected to each other before placement, and
2. which nearby boundary tiles could reach an ingress before placement.

It does **not** scan every protected room door/humanoid and pathfind all of them.

**Example:** with 16 spawn points that are all mutually connected, the baseline records them as one ingress component rather than storing every possible spawn-to-spawn pair.

### second-stage baseline / protected baseline
A later baseline used **only after the candidate has actually created a newly cut-off area**.

At that point the code looks only at protected endpoints inside the affected area and records whether each one was valid/reachable **before** the candidate.

This lets the code distinguish:
- “the candidate broke this endpoint” from
- “this endpoint was already unreachable before placement.”

**Example:** if a Nurse was already in a strange path-invalid state before the player moved a plant, that pre-existing problem should not make an unrelated plant placement fail.

### component / connected component
A group of tiles or ingress points that can all reach one another.

Think of it as an **island of connectivity**.

**Example:** if a wall divides a corridor into two disconnected halves, each half is a separate connected component.

### ingress component
A group of ingress tiles that were mutually connected **before** the candidate was placed.

The code can then test one representative from each component instead of checking every ingress against every other ingress.

**Example:** 16 spawn points in one connected hospital form one ingress component.

### representative
One tile chosen to stand in for an entire connected component during pathfinding checks.

Because every tile/ingress in that component was already known to be connected in the baseline, checking against one representative is usually enough.

**Example:** if 16 ingress points form one component, the first ingress can be used as that component's representative.

### boundary tiles
Walkable tiles immediately around the candidate's footprint or proposed room boundary that are used as **local probes for connectivity changes**.

They are not “all tiles on the map” and they are not necessarily the candidate tiles themselves.

**Example:** for a plant occupying one tile, the nearby walkable tiles around it are boundary tiles. If placing the plant cuts one side away from the other, those boundary tiles reveal the change.

### blocked area / no-ingress component
A connected group of **still-walkable tiles** that, under the candidate topology, can no longer reach any ingress.

This is a very important distinction: **“blocked area” does not mean every tile in it is non-passable.** The area can be perfectly walkable internally; it is “blocked off” because it has been separated from the hospital's ingress network.

**Example:** four plants surrounding one empty floor tile can create a one-tile blocked area. The centre tile is still floor, but nothing can enter or leave it.

### blocked tiles / affected tiles
The complete set of tiles belonging to a newly-created blocked area.

The code flood-fills from the detected blocked component and stores these tiles in a lookup table. Later checks can then ask, cheaply, “is this door/humanoid inside the affected area?”

**Example:** if a placement cuts off a 3x4 pocket of corridor, those 12 reachable-within-the-pocket floor tiles become the affected tile set.

### newly blocked
Disconnected **because of this candidate**, rather than already disconnected beforehand.

This is why the baseline matters: the patch tries not to reject a placement merely because the loaded hospital already contains an unrelated connectivity problem.

### impact / connectivity impact
A meaningful change caused by the candidate to the pre-existing walkable network.

In this patch, the important impacts are principally:
- splitting ingress points that were connected before, or
- creating a new component that used to reach ingress but no longer does.

If there is no such impact, the expensive protected-endpoint stage is skipped.

### first pass
The cheap, impact-first check while candidate topology is active.

It answers questions such as:
- did a previously connected ingress component split?
- was a new no-ingress component created?
- are candidate-specific required tiles still connected?

Only if this pass finds a newly blocked area does the protected-endpoint stage run.

### second stage
The protected-endpoint check performed after the first pass has identified newly blocked tiles.

It deliberately restricts work to endpoints located inside that affected tile set.

### prospective
Another word used in the patch for **“hypothetical / if we placed it.”**

“Prospective room topology” therefore means “the room connectivity we would have if the current blueprint were committed.”

### baseline topology
The connectivity state that existed before the candidate change.

For a moved object, this can require temporarily restoring the existing object's original pathfinding effect before measuring protected endpoints, so the comparison is truly “before move” versus “after move.”

### rollback / restore
Undoing temporary pathfinding changes after a prospective check.

The candidate topology is only simulated. The map flags must always be returned to their original values after the check, including when an error occurs.

### pathfinding flag
A map flag used by the pathfinder to describe whether travel is allowed in a direction or whether a tile is passable.

**Example:** `travelNorth`, `travelSouth`, `travelEast`, and `travelWest` describe directional movement between neighbouring tiles.

### usage tile / use position
The tile where a humanoid logically stands to use an object.

This can differ from the tile occupied by the object's graphic.

**Example:** a Reception Desk occupies its own tile, while its receptionist/patient interaction positions are adjacent usage tiles.

### logical humanoid position
The position that should count for connectivity, even when an animation temporarily renders or records the humanoid on another tile.

**Example:** while a Nurse is using a sofa, the animation may temporarily put the entity on a non-passable sofa/render tile. The patch uses the saved pre-use walking tile when available so the animation does not create a false placement failure.

### pre-existing invalid endpoint
A protected endpoint that was already unable to reach ingress before the candidate was applied.

The candidate did not cause that problem, so the patch logs/ignores it rather than blaming the current placement.

### strict check / strict fallback
The older/local reachability rule that is still used on special maps or situations where the normal spawn-point assumptions are unavailable.

It is a fallback, not a second definition of ingress.

### flood fill
A standard way of finding every tile in one connected region: start from one tile, visit all reachable neighbours, then their neighbours, and continue until the whole component has been collected.

The patch uses this to turn a detected newly blocked component into the full affected-tile set.

### network
In comments/functions such as “door network valid,” this means the hospital's **walkable connectivity network**, not a computer network.

## Short worked example: four plants around one floor tile

Imagine one empty corridor tile with three sides already blocked by plants, and the player previews a fourth plant:

1. The fourth plant is the **candidate**.
2. The surrounding reachable floor tiles are the **boundary tiles**.
3. Before placement, the code captures the **impact/ingress baseline**.
4. It temporarily applies the **candidate topology**.
5. The centre floor tile is still passable, but it can no longer reach any **ingress**.
6. That centre tile is therefore a new **blocked/no-ingress component**.
7. A flood fill produces the **affected/blocked tile set** (one tile in this example).
8. Only now does the code look for **protected endpoints** inside that tile set.
9. If the tile is empty, there are none, so the placement can be allowed without pathfinding every door/humanoid in the hospital.
10. If a protected endpoint is inside it, the **protected/second-stage baseline** tells us whether that endpoint was valid before the candidate. If it was, the candidate would newly trap it and the placement is rejected.

## Short worked example: moving an object

If an existing object is being moved rather than a brand-new object being placed, there are effectively three states to keep straight:

1. **original/baseline topology** — object at its old position,
2. **candidate topology** — object at the proposed new position,
3. **restored live state** — whatever state the UI needs after the check finishes.

The helper wrappers exist largely to make sure those temporary transitions are undone correctly.

If there are other terms in the patch that are unclear, they can be added here without changing the implementation itself.
