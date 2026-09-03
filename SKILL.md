---
name: easyeda-schematic
description: Create, redraw, modify, audit, and visually verify EasyEDA Pro schematics through the Run API Gateway. Use for EasyEDA schematic-page work that requires page-bound placement, electrical checks, compact layout, power/GND conventions, or rendered-image QA. Do not use for PCB layout, generic circuit theory, or non-EasyEDA CAD tasks.
metadata:
  version: "1.0.1"
  short-description: Draw and verify EasyEDA schematics
---

# EasyEDA Schematic

Produce electrically correct, compact, readable EasyEDA Pro schematics and verify the actual rendered result before reporting completion.

## Rule Source and Supporting References

This skill contains the maintained drawing rules and acceptance checklist; no separate workstation drawing-standard file is required. Follow the user's current requirements and confirmed project conventions. Treat layout defaults as choices that serve electrical intent and readability, not as reasons to override a verified arrangement. When maintaining this skill, retain verified newer rules over conflicting legacy material and add only useful gaps.

- Before live Gateway inspection or mutation, read [references/easyeda-gateway.md](references/easyeda-gateway.md).
- When diagnosing a repeated visual, API, or connection symptom, read [references/failure-patterns.md](references/failure-patterns.md).

## Task Mode and Scope

- **Review or diagnose:** inspect primitive data, electrical relationships, and renders; do not mutate unless the user asks.
- **Modify:** change only the requested page and affected functional block. Preserve unrelated content.
- **New drawing or independent redraw:** create new primitives. Use other pages and images only as visual references unless copying is explicitly authorized.
- **Monitor:** observe the Gateway only when explicitly requested.

Identify the exact project, page, connected window, and requested mode before acting. Do not assume the visible tab is the target.

## Workflow

### 1. Preflight

- Determine whether the target page is blank, contains content to preserve, or contains a failed attempt that is in scope to replace.
- Enumerate and read all page text, notes, images, and callouts. Record constraints such as chemistry, voltage, current, isolation domain, configuration mode, population option, and NC requirements.
- Query the page frame and title-block bounds before choosing coordinates. Keep all new content inside usable bounds, including the full rendered extents of symbols, owned text, notes, and images rather than only their origin points.
- Query existing components, pins, packages, attributes, wires, flags, and texts in the affected block; inspect the current render before mutation.
- Verify device pin functions and required operating conditions against a local or authoritative datasheet. Do not substitute a familiar default for an explicit page note.
- A user-designated reference page such as P15 may define target density, typography, and composition, but never copy its primitive IDs, wires, absolute coordinates, or contents into the target page without explicit authorization.
- When another page is opened for comparison, treat it as read-only, then explicitly reopen and re-identify the target page before any mutation. Never rely on the previously active tab after a reference-page inspection.

### 2. Plan Around Pins and Local Loops

- Default to left-to-right reading flow and align related pins and components to the working grid. Keep control and feedback branches near their pins, and distinguish functional groups with useful spacing. Electrical intent and readability take priority over symmetry or equal spacing.
- Anchor the main IC, then form compact functional groups around its pin locations. Typical groups include input/decoupling/protection, switching node/diode/inductor, output or battery/sense/capacitors, status indicators, and regulator-reference decoupling.
- Place key support parts close to the IC pins they directly connect, minimizing the pin-to-part-to-pin path before arranging the remaining branches and labels. For example, move R2 close to BAT and VS first, then organize C2 and C3 around the BAT/VS/GND nodes; a horizontal C2 can share C3's ground. Do not preserve a distant support-part position merely to follow existing rails or accept a smaller outer outline as sufficient compactness. Keep pin identities, electrical domains, and readable text clearance intact.
- Choose each component orientation to align its pins with current flow and nearby IC pins. Same-class parts need not share a rotation when different orientations produce cleaner loops.
- For a two-terminal part connecting two nearby nets, consider placing it directly in the free space between those nets instead of extending a separate branch beyond the block. For example, a horizontal freewheel diode can bridge a capacitor ground node and the LX rail, share the existing GND flag, and remove a downward detour. Reserve space for its native designator/value, adjust the local rail if needed, and preserve the exact pin-to-net polarity; shared ground is valid only within the same electrical domain.
- Interpret “power above, GND below” within each local branch: the supply node is above its load or capacitor, and its ground return is below. This is a relative layout principle, not a mandatory symbol rotation or a requirement that every power flag sit above every GND flag. A horizontal VCC_BAT flag beside the BAT/C3 upper node, with C3 and its GND below, fully satisfies the principle; it is not an exception.
- Join adjacent pins of exactly the same net at their nearest usable endpoints with a short straight segment, then place one native flag at an end junction (for example, below one of two downward GND pins). Do not extend both pins into a U merely to center the flag. For a shared side rail, place the flag on an existing pin-level endpoint when that removes a separate intermediate branch; for example, extend the pin 12 line directly to GND instead of adding a branch between pins 12 and 11. Keep the complete flag body and native name clear of unrelated routes; absence of a junction dot does not excuse visual contact.
- For pins already confirmed to share a net, choose the main feed level together with the support-component and owned-text positions. For example, feeding the upper of two VIN pins and branching down to the lower can let the input capacitor move up, shorten its ground lead, and place its labels in the clear space between capacitor and IC. Compare the entire group rather than preserving the old trunk and arranging parts around it; the upper pin is a layout choice, not a universal rule.
- Choose the flag orientation at the connected node that keeps the name readable and the connection short. Never add an upward detour, an avoidable crossing, or a perimeter rail merely to make a power symbol point upward. Keep a short finite lead where needed for reliable connection and symbol clearance.
- Prefer a local native power or ground flag when it shortens routing and the electrical domain is unambiguous; share a symbol only for exactly the same net. Plan same-net supply connections for the whole local functional group before fixing individual flags. Nearby branches and an IC supply pin can share a short local rail; let each pin reach it along its axis where practical. For example, VIN and two indicator resistors can share an upper rail with one horizontal power flag at its end, removing separate supply stubs and the extra upward flag branch. Keep supply hierarchy clear and retain separate flags when sharing would introduce crossings, long routes across other groups, or ambiguous domains.
- Space repeated branches using their complete rendered bounds, including native designators, values, and details such as LED emission arrows. Reduce column spacing while preserving readable clearance, and align each branch with its destination IC pin where useful; symbol-body spacing alone is not a sufficient clearance check.
- Reserve space for all owned text and any useful circuit-parameter or `PCB Layout Note:` text before routing.
- Apply circuit-specific grouping to the actual topology: keep LDO input/output capacitors near their respective pins and a fixed EN branch short; for a buck stage, group the input capacitor, switch, and required freewheel path compactly, then inductor/output capacitor. Make feedback pickup and its separation from switching nets clear. Derive any PCB routing requirements from the device documentation; schematic distance alone does not establish PCB loop quality.

### Network Names and Domains

- Preserve established project net names. For new names in the user's naming style, examples include `VCC_5V`, `VCC_3V3`, and isolated `VCC_5V_EX`; retain existing `VDD`, `VDDA`, or `VREF` where applicable. These examples do not authorize renaming an existing circuit.
- Treat `GND`, `AGND`, `GND_EX`, and different supply domains as distinct nets; connect them only at an explicitly intended connection. Pair isolated supply and return domains correctly, and check that labels or shared flags do not bridge the isolation boundary.
- Use native labels for cross-page, cross-block, or distant connections when they improve clarity. Avoid repeated labels in a small local net, and keep multiple local flags when consolidation would require detours or obscure functional grouping.

### 3. Draw or Modify Incrementally

- Work one functional group at a time and make the first created state the intended state.
- Place components first, immediately query their `Designator` and `Name` attributes, and reserve their rendered bounds before adding wires.
- Before calling `sch_PrimitiveComponent.modify`, capture an immutable deep copy of the complete component state and all owned attributes; an async state instance can mutate the queried object by reference, making a shallow “before” snapshot unreliable. In the current editor build, a partial component modify can replace `otherProperty` and silently erase hidden `Value`, footprint, supplier, or datasheet fields. Do not use a partial component modify as a move shortcut; use the narrow dedicated API when available, or pass a complete verified state and immediately requery every preserved field.
- Use short orthogonal wires and explicit junctions. Optimize the whole electrical loop, not merely each visible segment.
- Create every ordinary local wire with its internal `net` omitted or set to `""` on the first call. Use native net labels, power flags, and ground flags only when visible naming improves clarity.
- A visible finite green segment is not inherently wrong. Keep it when required for connectivity, pin-axis alignment, symbol clearance, or composition; change it only when redundant, crooked, overlapping, or visually harmful.
- For diodes and LEDs, verify electrical polarity from pin identity and the connected source/sink path before judging the graphic. Record which physical pin is anode/cathode, then confirm the final parent rotation still connects those pins to the intended nets. The first segment must leave each pin on its axis; place any turn away from the symbol.
- Mark NC pins explicitly.
- Do not create new zero-length wires. Preserve user-created tiny or zero-length connector structures unless before/after primitive, DRC, and render evidence proves replacement is safe.
- Prefer `sch_PrimitiveComponent.createNetFlag(...)` for native power and ground symbols. Requery the parent and its native `Name` attribute immediately.

### 4. Place Flags and Owned Text

- Keep each designator, value, and native net name at its library-default or clearly adjacent position. Resolve a collision by moving or shortening the wire first, then moving the whole owning component/flag or local group; move text alone only when its default placement is inherently unsuitable.
- When a horizontal part has spare space beside its body but tight clearance to the nets above or below, place its native designator and value on opposite sides above the lead (for example, C4 on the left and 100nF on the right). Choose part position and text placement together: bring the part close to its owning IC pin, use the available lateral space, and keep both labels clearly associated with that part and clear of wires. Do not preserve a vertically stacked library layout when it crowds an adjacent net.
- In this SCH_AI workspace, visible passive-component designators and values default to `0.1 inch` unless the user reference or established local style requires another size. Query the actual `fontSize`; do not leave isolated `0.0675 inch` text inside an otherwise `0.1 inch` functional block.
- For a normal vertical GND, preserve the library-default orientation and placement when the render matches the standard. Its native `GND`, `AGND`, or `GND_EX` name must remain visible and visually centered beneath the symbol.
- For a horizontal GND, rotate or move the parent flag as one object. The body must face open space away from the circuit, the wire must terminate at the pin without crossing the body, and the native horizontal name must sit outside the shortest stroke, centered on the symbol centerline with a small clear gap.
- Query and render every created or relocated GND-family flag individually. A representative flag passing does not prove that another instance kept the same saved rotation, name visibility, or text position.
- For horizontal power or net flags on an inline component, keep both names outside their vertical strokes, on the selected wire-relative baseline, with a small clear gap. Mirrored flags can require different serialized `Name.y` or `alignMode`; judge the rendered geometry, not coordinate equality.
- Keep explanatory text concise: show only key operating parameters that prevent unnecessary datasheet lookup, followed when useful by a short PCB layout note. State relevant operating conditions and distinguish confirmed values from assumptions; do not repeat values already obvious on components or paste manual paragraphs.
- Place a functional-block title below the block or in the user-designated location, with parameter notes in nearby free space. Keep both outside the main signal path and title block. Remove obsolete/test/duplicate titles introduced or superseded by the current edit.
- When a PCB layout note is useful, end the parameter note with `PCB Layout Note:` and a few specific, documented placement, return-path, or sensitive-net requirements. Do not add generic filler merely to satisfy a template.
- Include a datasheet image only when text cannot explain the needed detail clearly. Crop it to the relevant figure/table, identify the device and figure or source page, and keep it legible inside the frame. An image never substitutes for actual schematic connectivity.

### 5. Compactness Pass

After the initial render, inspect the block as a composition:

- compare its rendered bounding box with the functional content it contains;
- find the longest horizontal and vertical wires and ask whether local grouping or flags can shorten them; inspect both group width and height: shorten excess rail-to-part and part-to-part leads as well as column spacing, preserving finite connections, pin-axis alignment, and useful text clearance;
- check part-to-pin distance for each support component, especially parts connecting two related IC pins; shorten avoidable connecting paths before optimizing the outer outline;
- inspect the input, switching, output/battery, status, and decoupling loop footprints;
- remove avoidable perimeter rails or wires that travel around unrelated groups;
- judge compactness by loop area, routing length, whitespace, and readability, not by symbol count alone. A longer individual segment can improve the group when it enables a clear shared supply and removes separate flags or detours; do not optimize each segment in isolation.

If a rail spans unrelated groups or encloses the block, redesign the local connections before saving.

### 6. Verify and Save

- Requery every changed primitive, owned attribute, and wire. Confirm pin intent, endpoints, junctions, net separation, flag types, and surviving IDs after wire merges.
- For every polarized part, compare the saved parent rotation and actual pin-to-net mapping with the circuit's current direction. A visually neat symbol is not accepted until anode/cathode or positive/negative pin connectivity is proven.
- For every modified component, compare its post-change `Value`, footprint, supplier/manufacturer data, datasheet fields, and visible `Designator`/`Name` against the pre-change snapshot. A visually correct move is a failed edit if metadata was lost.
- Assert that each changed ordinary local wire has `net === ""` unless visible wire text was explicitly requested.
- Before saving, define a local-render checklist containing every dense functional group and every region changed during the task. Each listed region must be rendered at a scale where the smallest designator, value, native net name, junction, and symbol stroke are legible, and the model must actually inspect that image. Coordinates, API success, or a full-page overview do not satisfy this gate.
- Each local render must be checked for text-to-text, text-to-wire, text-to-symbol, wire-through-symbol, reversed symbol, crooked first lead, unclear crossing/junction, excessive whitespace, and avoidably long routing. A region passes only when every applicable item is clear.
- Any later mutation inside or adjacent to a previously checked region invalidates that result. Wait for editor state to settle, render that region again, and recheck it before saving.
- After all local regions pass, inspect one full-page render for frame/title-block clearance, composition, relative density, and missed outliers. The full-page render complements but never replaces the enlarged local checks.
- Compare density, typography, orientation, alignment, and whitespace with the user's reference or designated benchmark page.
- Run DRC where available and investigate fatal errors, especially coincident-but-unconnected endpoints.
- Attribute DRC findings to their page and affected primitives. Inspect errors and new findings on the current page; defer warnings from untouched pages until those pages are in scope. Do not treat an aggregate warning count as a current-page result or change component parameters just to clear unrelated warnings.
- Save only after electrical, structural, and visual checks pass. Requery saved state and render again when library, merge, or save behavior may have changed it.

## Acceptance Checklist

Before reporting completion, all applicable items must pass:

- exact target page/window confirmed; unrelated content preserved;
- every page note and constraint reconciled with the circuit;
- all content inside the frame and outside the title block;
- electrical intent, pin connections, NC state, domains, endpoints, and junctions verified;
- changed ordinary wire `net` fields empty;
- functional groups compact, support parts close to their pins, and no avoidable perimeter rail;
- orientations minimize loop area and keep diode/LED leads on-axis;
- local flags used only where they shorten and clarify the exact same net;
- SCH_AI passive designator/value typography consistent, normally `0.1 inch`;
- every GND-family native name visible, close, correctly oriented, and geometrically aligned;
- horizontal power/net names outside their strokes, aligned to the intended baseline, and neither touching nor floating;
- no owned text intersects a wire, junction, symbol body, or neighboring text;
- no new zero-length connector or failed-call leftover remains;
- every dense/changed region listed, enlarged, legibly rendered, and passed after its final mutation;
- full-page render inspected after all mandatory local renders passed;
- schematic saved and saved primitives requeried.

## Failure Handling

- Gateway requests are not transactional. After any failed execute request, requery exact old and new IDs before retrying or continuing.
- Stop live mutation when the Gateway is disconnected, the target page/window is ambiguous, a required symbol or pin definition cannot be verified, or the change would affect unrelated content.
- Use [references/failure-patterns.md](references/failure-patterns.md) to diagnose known symptoms and [references/easyeda-gateway.md](references/easyeda-gateway.md) for connection recovery and API mechanics.

## Gateway Helper

Use [scripts/invoke-easyeda-gateway.ps1](scripts/invoke-easyeda-gateway.ps1) for deterministic port discovery and JSON requests. It does not broaden authorization.

## Completion Report

State the target project/page, what changed or was reviewed, important electrical choices or assumptions, the structural/rendered/saved checks performed, and any remaining blocker. Do not make the user infer whether the page was saved or visually inspected.
