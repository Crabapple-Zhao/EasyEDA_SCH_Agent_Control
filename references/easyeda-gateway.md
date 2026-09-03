# EasyEDA Run API Gateway

Read this reference only when the task requires live EasyEDA inspection or mutation.

## Connection Model

- Expected localhost port range: `49620`–`49629`.
- Common endpoints:
  - `GET /health` — gateway and EasyEDA connection state;
  - `GET /eda-windows` — connected EasyEDA window IDs;
  - `POST /execute` — execute JavaScript in the selected EasyEDA window.
- An execute request uses JSON:

```json
{
  "windowId": "optional-window-id",
  "code": "return { ok: true };"
}
```

Use the exact connected window ID. Do not reuse a stale ID after a reconnect without checking `/eda-windows`.

## Startup and Slow-Connection Recovery

Start the Bridge before EasyEDA whenever possible. Run API Gateway v1.0.5 scans ports `49620` through `49629` serially with a 1.5-second timeout per port. When no Bridge is present, one failed pass can take roughly 15 seconds; five passes plus retry delays can approach 90 seconds.

Use the Bridge launcher configured on the current workstation; discover its actual installed location rather than assuming a fixed workspace path. The Bridge runtime is an external prerequisite, not bundled with this skill. An existing logon task (for example `Codex EasyEDA Bridge`) may already start it. Query the existing configuration before changing it. Creating, replacing, disabling, or deleting a startup task is an external system mutation and still requires the user's authorization.

The v1.0.5 reconnect implementation closes and immediately re-registers a fixed WebSocket ID. Repeated reconnect actions can keep invalidating an in-flight scan or race the previous close, so use this recovery sequence:

1. Verify that one port returns `/health` with `service: "easyeda-bridge"`.
2. If `edaConnected` is false, trigger reconnect once only.
3. Observe the Bridge log or TCP table for up to one complete scan interval. Do not repeatedly reconnect while a scan is active.
4. If no TCP/WebSocket attempt reaches the healthy Bridge, save the project and fully restart EasyEDA while leaving the Bridge running. This resets the stale extension runtime and lets activation connect to the already-listening server.
5. Requery `/eda-windows` and use the newly registered window ID.

A controlled cold-start test on this workstation established an additional v1.0.5 behavior: after an established Bridge was stopped and relaunched, the extension did not reattach automatically for more than one minute. Once `/health` was stable, a single reconnect attached immediately on port `49620`. Therefore the logon task prevents the normal boot-order failure, but a Bridge crash or manual restart during an open EasyEDA session still requires exactly one reconnect after health is restored.

Interpret connection evidence precisely:

- no `/health` response: Bridge is not running or is on a different port;
- healthy Bridge, `edaConnected: false`, and no incoming TCP/WebSocket attempt: EasyEDA extension runtime has not initiated a usable connection;
- established WebSocket but no registered window: handshake or registration failed;
- `edaConnected: true`: still requery `/eda-windows` because reconnecting changes the window ID.

Do not use the extension manager as a generic connection repair step. If the `API Gateway` menu and About dialog are available, the extension is loaded; do not toggle its enabled state unless the user explicitly asks or direct evidence shows it is disabled.

## Helper Script

From the skill directory:

```powershell
./scripts/invoke-easyeda-gateway.ps1 -Action discover
./scripts/invoke-easyeda-gateway.ps1 -Action windows
./scripts/invoke-easyeda-gateway.ps1 -Action execute -WindowId '<id>' -Code 'return Object.keys(eda);'
```

Specify `-Port` only when a known live port should be used.

## Read Before Write

Before a mutation, query the exact target primitive and page. Record the primitive ID and relevant state. Restrict edits to the requested page and functional block.

Useful API families commonly include:

- `eda.sch_PrimitiveComponent`
- `eda.sch_PrimitiveAttribute`
- `eda.sch_PrimitiveWire`
- `eda.sch_PrimitiveText`
- `eda.sch_Document`
- `eda.dmt_EditorControl`

When a method is unclear, inspect its prototype non-destructively:

```javascript
function methodNames(object) {
  const names = [];
  for (let current = object, depth = 0; current && depth < 3; current = Object.getPrototypeOf(current), depth += 1) {
    names.push(...Object.getOwnPropertyNames(current));
  }
  return [...new Set(names)];
}
return methodNames(eda.sch_PrimitiveComponent);
```

## Mutation Pattern

1. Query the current page and target IDs.
2. Apply the smallest scoped create, modify, or delete operation.
3. Wait briefly for asynchronous editor state to settle.
4. Requery the changed primitive and its owned attributes.
5. Render the affected region and inspect the image.
6. Save with `eda.sch_Document.save()` only after checks pass.
7. Requery saved primitives and render again when needed.

Do not treat a successful request as proof that the visible editor changed correctly.

### Component Modify Is Destructive When Partial

In the current EasyEDA Pro API build, `sch_PrimitiveComponent.modify(id, partialState)` does not reliably merge nested component metadata. A call intended only to move or rotate a component can replace `otherProperty`; omitted keys may be cleared. This can silently remove the hidden `Value` used by a visible `Name` expression such as `={Value}`, as well as footprint, supplier, LCSC, or datasheet metadata.

- Never call `sch_PrimitiveComponent.modify` with only `x`, `y`, or `rotation` after reading only top-level fields.
- Before any unavoidable component modify, make an immutable deep snapshot of the complete component object and every owned attribute returned by `sch_PrimitiveAttribute` (for example with `structuredClone` or JSON serialization of plain returned data). Do not retain only a live object reference: `toAsync()` state changes can mutate that object, corrupting the “before” comparison.
- Prefer a narrower dedicated operation when one exists. Modify a value or label with `sch_PrimitiveAttribute.modify`; do not route that change through the parent component.
- For a position or rotation change, an async component instance obtained from the complete queried object can preserve metadata more reliably: change only the required `setState_X`, `setState_Y`, or `setState_Rotation` field, call `done()`, then compare the full before/after component and owned-attribute snapshots. Do not assume this behavior for attribute instances, which use different coordinate conventions.
- If component modify is unavoidable, preserve the complete verified metadata payload, then immediately requery `Value`, `Designator`, `Name`, footprint, supplier/manufacturer, datasheet fields, and rendered text before proceeding.
- Treat any lost field as a failed mutation. Restore it before routing, saving, or moving another component.

## First-Write Wire Rule

In the current API, `sch_PrimitiveWire.create` accepts the wire geometry first and the wire `net` value second:

```javascript
await eda.sch_PrimitiveWire.create(line, "", null, null, null);
```

For a simple segment, pass a flat numeric geometry such as `[x1, y1, x2, y2]`. A nested point array such as `[[x1, y1], [x2, y2]]` failed in the current editor build. Requery the returned wire because connected segments may merge and the returned primitive ID may not survive.

A merged wire returned by `getAll()` can contain a flat list of separate segment quadruples. Do not assume that serialized list is valid input to a single `create` call: a branched list failed in the verified editor build. Rebuild branched geometry with separate finite `[x1, y1, x2, y2]` create calls, then requery the merged result and surviving IDs.

For an ordinary local wire, pass `""` or omit the net value from the first creation call. A non-empty internal `net` may be rendered by EasyEDA as blue text along the wire. It must not be used as invisible connectivity metadata.

When a visible name is required, use the native object intended for that purpose:

- power flag for a power rail;
- GND/AGND/GND_EX net flag for ground;
- native net label for a long-distance, cross-block, or cross-page signal.

Do not create every wire with a temporary net name and later clear it. Connected wire creation can merge segments and retain a different primitive ID, so cleanup is slower and less reliable than creating the correct representation once.

Immediately audit the changed wires after a block is routed:

```javascript
const changedIds = new Set(idsCreatedOrTouched);
const changed = (await eda.sch_PrimitiveWire.getAll())
  .filter((wire) => changedIds.has(wire.primitiveId));
return changed.map((wire) => ({
  primitiveId: wire.primitiveId,
  net: wire.net,
  line: wire.line,
}));
```

For ordinary local wires, fail the local QA step if `wire.net !== ""`. Do not clear unrelated pre-existing wires outside the requested functional block.

Do not create new zero-length segments. Coincident part-pin and net-flag endpoints are not guaranteed to form an electrical connection and can produce the DRC fatal error `端点重叠且未连接`; new API geometry should normally separate them by a usable grid interval and use a finite connector. Existing user-created zero-length or tiny connector primitives may be editor connectivity artifacts, so do not delete them based only on geometry. Capture the local primitives and DRC state first; if replacement is necessary, preserve the native flag type and prove equivalent appearance and connectivity afterward.

Visible green wire is not itself a defect. Retain a finite segment when it is electrically necessary or provides useful symbol/text clearance. Shorten, reroute, or remove it only when it is redundant, off-axis, overlapping, or makes the composition worse.

For a diode or LED, route the first segment collinearly with the pin axis. Avoid a short perpendicular hook immediately at the pin; place any orthogonal turn farther from the symbol.

Before rotating a diode or LED, identify its anode and cathode pins from the library symbol and verify the intended current path. For an active-low open-drain status output, the usual path is `positive rail -> resistor -> LED anode`, with the LED cathode connected to the sinking output. A 180-degree-cleaner-looking rotation is still wrong if it reverses that pin-to-net mapping. Requery the saved parent rotation and inspect both ends in the rendered crop.

When removing geometry from an already merged wire network, do not treat a successful `sch_PrimitiveWire.modify` response or data requery as proof that stale rendered segments disappeared. Delete only the exact affected merged wire primitives, rebuild the intended topology from short finite segments with `net: ""`, then requery the surviving wire IDs and render the region.

## Net-Flag and GND Handling

Manual UI placement normally shows the native GND name in a sensible default position. An API-created net flag can return a different serialized attribute state, including `Name.valueVisible === false`; therefore query instead of assuming UI defaults.

Prefer the dedicated API for native flags:

```javascript
await eda.sch_PrimitiveComponent.createNetFlag("Ground", "GND", x, y, rotation, mirror);
```

Use `"Power"`, `"Ground"`, `"AnalogGround"`, or `"ProtectGround"` as appropriate. In the current build, `createNetFlag` preserved the native GND name relationship and default visibility more reliably than generic component creation. Still requery the parent and owned attributes because horizontal power flags can return a rotated or inward-facing native `Name` position that needs a minimal adjacent correction.

For each created ground flag:

1. Query the parent component and confirm `componentType === "netflag"` and the correct `net` value.
2. Query all owned attributes and find the native `Name` attribute. Never add a separate text object reading `GND`.
3. For a normal vertical GND, preserve the library-default position and rotation. If only visibility is wrong, modify only visibility:

```javascript
await eda.sch_PrimitiveAttribute.modify(nameAttributeId, {
  valueVisible: true,
});
```

4. For a horizontal GND, rotate or move the parent net flag as one object, requery all owned attributes, then keep the native name horizontal and close to the symbol's outside edge.
5. Render the affected region immediately. For a side-facing flag, check the parent pin direction as well as the label: the symbol body and native name must face open space away from the IC, and the wire must stop at the flag pin rather than run through the body. If the symbol faces the chip or crosses a wire, rotate the parent flag by 180 degrees or move/reroute the owning connection; do not move only the name.

Do not duplicate a GND placement pattern until one representative instance passes the rendered check. After duplication or relocation, every GND-family instance must still be queried and rendered individually; API-created instances can differ in native `Name.valueVisible`, child coordinates, or saved orientation.

The saved parent `rotation` reported for a net flag can be normalized differently from the value returned by its creation call. Treat the final pin direction, child-symbol position, wire termination, native-name placement, and rendered appearance as authoritative; never approve a side-facing GND from the requested numeric rotation alone.

`sch_PrimitiveComponent.modify` can reject net flags even when it works for normal parts. To relocate a net flag, create and verify the replacement first, delete only the exact old primitive ID, reconnect it with finite wire geometry, and then requery. If any execute request fails, assume the batch may have committed partially: inspect old IDs, new IDs, wires, and attributes before the next mutation.

## Attribute Coordinate Safety

Prefer `sch_PrimitiveAttribute.modify` for small attribute changes. It accepts logical editor coordinates and performs the API's Y conversion. In the current editor build, an instance obtained with `get(...).toAsync()` can expose internal state conventions; `setState_Y()` may expect an internally inverted Y value. Mixing these approaches caused attributes to jump or appear far from their symbols.

Rules:

- For visibility-only changes, send only `valueVisible`; do not resend x/y/rotation.
- For rotation-only changes, send only the intended rotation and visibility, then requery.
- Change x/y only when the library-default relative position is unusable.
- If coordinates must change, use one API style consistently, requery the resulting logical x/y, and render before any further drawing.
- Never call `done()` on a partially understood attribute state and assume untouched coordinates were preserved.

## Owned-Text Collision Check

Component designators and values may extend beyond the symbol body. Query them immediately after component placement and reserve their rendered area before routing. The same applies to native power/GND names.

After routing a dense block, render an enlarged crop and explicitly inspect:

- capacitor designator/value versus both capacitor leads and nearby vertical rails;
- inductor designator/value versus the winding and crossing vertical wires;
- IC designator/value versus side-facing GND symbols and pin names;
- GND name versus symbol strokes, junction dots, and wire segments.

If an owned label overlaps, move/reroute the wire first or move the whole owning object. Move the label alone only when the library default is intrinsically unsuitable, and keep it adjacent.

## Rendering

Use the editor's rendered-image API rather than relying on coordinates alone. A typical pattern is:

```javascript
await eda.dmt_EditorControl.zoomToRegion(left, right, top, bottom);
await new Promise((resolve) => setTimeout(resolve, 400));
const blob = await eda.dmt_EditorControl.getCurrentRenderedAreaImage();
return { type: blob.type, size: blob.size };
```

Transfer or inspect the returned image using the host's available image-viewing mechanism. The model must actually look at the rendered result.

### Mandatory Settled-Render Gate

- Use `eda.dmt_EditorControl.getCurrentRenderedAreaImage()` as the normal inspection path. Do not invoke general computer control merely to look at a schematic when the Gateway preview is available; use it only as a fallback when the render API cannot provide the required view.
- After a mutation, first requery the affected primitives and wait for the editor to settle. For a multi-object or merged-wire change, require two consecutive equivalent primitive queries or renders before treating the displayed state as final. A single immediate frame can be stale.
- Build an explicit list of every dense functional group and every changed region. Call `zoomToRegion(...)` for each one and inspect a legible crop. Required groups commonly include input/decoupling, switching, output/battery, status indicators, control/feedback, side-facing flags, and any relocated text.
- Check each crop for all owned text, symbol direction, first-lead alignment, wire termination, crossings, junctions, native flag names, and useful whitespace. If text is too small to judge, the crop does not count.
- Any mutation affecting a checked crop invalidates it. Wait, requery, rerender, and inspect again.
- Only after every local crop passes, call `zoomToAllPrimitives()` or an equivalent full-page view. Never use the full-page image as evidence that small overlaps are absent.

## EasyEDA-Specific Pitfalls

- In the current schematic API, larger logical Y values render higher on the page. Always verify visually.
- A non-empty `Wire.net` can become visible blue text. Ordinary local wires must be created with an empty net from the start.
- Component moves may not leave designator and value attributes where expected. Requery owned attributes after moving.
- A partial `sch_PrimitiveComponent.modify` can replace `otherProperty` and erase hidden values or sourcing/footprint metadata. Snapshot the full component and owned attributes first; do not use partial component modify as a move shortcut.
- `sch_PrimitiveComponent.modify` may be limited to normal parts; net flags can require exact-ID replacement. Verify that the old flag is truly gone and the new native name is visible.
- Creating a connected wire may merge it into an existing wire and return or retain a different primitive ID. Requery all affected wires.
- Returned wire IDs are provisional after merging; track the IDs that survive `getAll()`, not only the IDs returned by `create`.
- An execute request is not transactional. A later failure can leave earlier creates or deletes committed; always requery actual state after an error.
- Coincident component/net-flag pins may still be electrically separate. Do not create a new zero-length wire as the apparent connector; use a finite segment for new API work. Treat pre-existing user-created tiny/zero connectors as potentially meaningful until before/after DRC and render prove they are safely replaceable.
- Removing topology from a merged wire can require exact deletion and reconstruction; verify both serialized geometry and the rendered image.
- Attribute enumeration may differ from direct lookup. When needed, use `getAllPrimitiveId()` and batch `get(...)`, then filter by `parentPrimitiveId`.
- A newly created GND flag may have its native `Name` attribute hidden. Change visibility only and preserve the default adjacent position for a normal vertical symbol.
- Rotating a child GND graphic or name independently can reverse the symbol or detach the name. Rotate the parent net flag, then requery its children.
- Instance attribute state setters can expose internal Y conventions. Prefer static `modify` for small changes and verify the rendered result immediately.
- Saving can return little or no payload. Verify saved state by requerying primitives and inspecting the rendered page.
- The editor can display a stale intermediate frame immediately after a batch. Require settled state and rerender mandatory local crops after the final mutation.

## Stop Conditions

Stop live mutation and report the blocker when:

- no Gateway is reachable;
- no EasyEDA window is connected;
- the target page cannot be identified safely;
- the required library symbol or pin definition cannot be verified;
- the requested change would require modifying unrelated or ambiguous content.
