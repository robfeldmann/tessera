---
type: research
observed: 2026-10-23
status: open
description: Which catalog requirements need focus, pointer, scroll, or the clock before they can be tested, where each goes under the capability subsections, and the behaviours no requirement covers yet.
---

# Catalog capability requirements audit

## Question

The owner decided (2026-10-23, [plan 036](../plans/phase-4-view-layer-and-developer-tooling.md) Decisions) that each catalog doc's `## Requirements` gains `### Focus`, `### Pointer`, `### Scroll`, and `### Clock` subsections for requirements that can't be tested until that capability lands. Which of the catalog's 1071 requirements go where, and which behaviours that the designs commit to have no requirement at all?

## Method

Four classifier agents marked every requirement for one capability each; an independent engineer judged, without reading any Requirements section, whether each of the 43 in-scope components owns or affects each capability and which behaviours it commits to; a second engineer placed every marked requirement by the latest-landing rule (Focus, then Pointer, then Scroll, then Clock), resolved the borderlines, and matched each committed behaviour to a requirement, drafting one where none existed. Nothing in the catalog was edited. Status stays `open` until the owner reviews the drafted gap requirements and the disagreements; the restructuring then applies the placements and the accepted drafts.

Inputs: `requirements.tsv` (1071 rows), `req-merged.jsonl` (319 marked rows), `participation.jsonl` (43 docs), classifier `why` fields in `req-{focus,pointer,scroll,clock}.jsonl`, and the source docs under `docs/design/` where a verdict turned on doc text. Read-only; no doc edited.

Landing order: Focus < Pointer < Scroll < Clock. Rule: a requirement goes under the capability that lands LAST among those it needs; negative assertions ("installs no responder") go in the subsection of the capability whose machinery they need. Conventions used below:

- **Resolving a NodeState offset.** An offset that is `NodeState` (List, Table, Outline, Form, Picker/MultiPicker menus) is zero until input or reveal moves it, so any assertion that observes a non-zero offset is Scroll. An offset that is a `Binding` (ScrollView) can be set by the test, so clamp/geometry assertions on it are plain.
- **Combined negatives.** The catalog already writes "takes no focus, keys or pointer input" as one requirement (text.md:371, image.md:394, markdown.md:506). Gap drafts follow that convention; the row lists both capabilities and the subsection is the later one (Pointer).
- **Paging.** PgUp/PgDn that move the SELECTION or CURSOR by the static viewport row count are Focus (see EXCEPTION rows); PgUp/PgDn/Home/End that move the OFFSET (ScrollView) are Scroll.

## 1. Placement

Table covers all 319 marked rows once each (`src=M`) plus 33 unmarked rows found to belong in a subsection (`src=ADD`). `none` means the borderline resolved to the plain list.

| loc | src | requirement name | subsection | note |
|---|---|---|---|---|
| primitives/background.md:147 | M | decorative backgrounds require explicit allows hit testing false | Pointer | Asserts the allowsHitTesting(false) opt-out; hit testing is Pointer machinery. |
| primitives/badge.md:325 | M | badge takes no focus and consumes no keys | Focus | negative focus and key-routing assertion |
| primitives/border.md:253 | M | self focus paints a heavy ring in the focus role without moving the ring | Focus | self focus state drives ring style |
| primitives/border.md:254 | M | focus within tints the nearest bordered ring at normal weight | Focus | focus-within state drives ring tint |
| primitives/border.md:255 | M | focused row shows the cursor and a bold focus label | Focus | focused-row cursor and label |
| primitives/border.md:256 | M | split divider and joints take the focus role as heavy lines | Focus | focused divider appearance |
| primitives/border.md:257 | M | bordered table outer ring follows the self or within focus rule | Focus | focus rule selects ring style |
| primitives/border.md:258 | M | heavy and double rings change colour only on focus | Focus | focus appearance |
| primitives/border.md:259 | M | ascii focus renders bold on the ascii ring | Focus | focus appearance under ASCII |
| primitives/border.md:260 | M | focus ring takes the focus role in every colour tier, with no hue | Focus | focus ring appearance |
| primitives/box.md:343 | M | self focus paints the heavy set in the focus role without moving the ring | Focus | self focus state drives ring style |
| primitives/box.md:344 | M | focus within tints the nearest bordered ring at normal weight | Focus | focus-within state drives ring tint |
| primitives/box.md:345 | M | focus within title takes the bold focus role | Focus | focus-within state drives title style |
| primitives/box.md:346 | M | nested focus tints only the nearest bordered ancestor | Focus | focus propagation through ancestors |
| primitives/box.md:347 | M | box with nothing focusable inside never changes | Focus | negative focus-within assertion |
| primitives/box.md:348 | M | focus within is off under focusSection or focusWithinBorder(false) | Focus | focus-within tint switch |
| primitives/flow.md:313 | M | flow item node state survives a reflow | Focus | focus identity survives reflow |
| primitives/overlay.md:117 | M | decorative overlay requires explicit hit-testing opt-out | Pointer | Asserts hit-testing opt-out for an overlay layer; needs hit testing. |
| primitives/scroll-indicator.md:377 | M | scroll indicator installs no focus binding input or drag handler | Pointer | caps focus+pointer; latest-landing -> Pointer. Negative assertion that no drag handler is installed; pointer drag routing is Pointer. |
| primitives/text.md:371 | M | text never consumes keyboard or pointer input | Pointer | caps focus+pointer; latest-landing -> Pointer. Negative assertion over mouse table (click, drag, wheel-up/down); pointer half needs Pointer, key half needs Focus. |
| primitives/view-that-fits.md:303 | M | unchosen candidates get a zero frame and render and hit test nothing | Pointer | Negative hit-test assertion for unchosen candidates. |
| primitives/view-that-fits.md:312 | M | an unchosen candidate keeps its node state until it is chosen again | Focus | BORDERLINE -> Focus. Node state lives on a candidate node; the earliest capability that gives a candidate mutable state is Focus (key-driven state: pressed, cursor). The ScrollView-clamp half of the trace is a Scroll behaviour and is drafted separately (Gaps: view-that-fits / scroll). |
| primitives/view-that-fits.md:313 | M | unchosen candidates are left out of the focus order | Focus | focus order membership |
| primitives/view-that-fits.md:314 | M | focus stays on a focus id that the newly chosen candidate also holds | Focus | focus retention across switch |
| primitives/view-that-fits.md:315 | M | focus clears when the newly chosen candidate lacks the focused id | Focus | focus removal handling |
| primitives/view-that-fits.md:316 | ADD | unchosen candidates still contribute terminal requirements | Focus | UNMARKED ADD. Terminal requirements aggregation belongs to slice 04 (focus and key routing; view-that-fits.md links terminal-requirements-aggregation). Participation lists it under Pointer via "mouse tracking" as the example; the machinery is Focus (see Disagreements D4). |
| widgets/button.md:579 | M | focused box draws its border heavy in focus | Focus | focused appearance |
| widgets/button.md:583 | M | focused filled button takes the focus fill with a bold contrast label | Focus | focused appearance |
| widgets/button.md:584 | M | focused filled button draws a default-foreground chip | Focus | focused appearance |
| widgets/button.md:585 | M | focused tinted button takes a faint focus fill with a bold focus label | Focus | focused appearance |
| widgets/button.md:586 | M | focused plain button underlines its label in focus | Focus | focused appearance |
| widgets/button.md:587 | M | pressed filled button takes the tinted look and pressed tinted takes the filled look | Focus | BORDERLINE -> Focus. isPressed is reachable from a focused phased key-down (Key table: Enter/Space), so the pressed look is testable at Focus without any pointer. |
| widgets/button.md:588 | M | pressed plain button renders its label bold | Focus | BORDERLINE -> Focus. Same as button.md:587: pressed is set by a focused key-down. |
| widgets/button.md:589 | M | hovered button underlines its label | Pointer | Hover state is pointer-derived (is hovered). |
| widgets/button.md:592 | M | NO_COLOR focus underlines the label | Focus | focus appearance under NO_COLOR |
| widgets/button.md:593 | M | ASCII focus adds bold to the label | Focus | focus appearance under ASCII |
| widgets/button.md:598 | M | filled button uses its full forced width as its touch-wide hit target | Pointer | Asserts the clickable region (hit target), which requires hit testing. |
| widgets/button.md:599 | M | button invokes its action exactly once for a phased enabled enter press and matching release | Focus | Enter key routed to focused responder |
| widgets/button.md:600 | M | button invokes its action exactly once for a legacy enabled enter press-only event | Focus | Enter key routed to focused responder |
| widgets/button.md:601 | M | button invokes its action exactly once for a phased enabled space press and matching release | Focus | Space key routed to focused responder |
| widgets/button.md:602 | M | button invokes its action exactly once for a legacy enabled space press-only event | Focus | Space key routed to focused responder |
| widgets/button.md:603 | M | legacy keyboard activation clears isPressed before dispatch returns | Focus | keyboard activation |
| widgets/button.md:604 | M | button cancels a pending press when focus or enabled state changes before release | Focus | BORDERLINE (pointer) -> Focus. The keyboard path (phased key-down, then focus loss or disable before release) fully exercises the rule; the pointer press-cancel variant is covered by the gap `button clears a pending press when a pointer release leaves its node` (Pointer). |
| widgets/button.md:605 | M | disabled button neither joins focus nor invokes or consumes activation input | Pointer | caps focus+pointer; latest-landing -> Pointer. Mouse table disabled-click negative assertion. |
| widgets/button.md:606 | M | button activates a primary pointer only when press and release hit the same button node | Pointer | Same-node click semantics; pointer press/release hit testing. |
| widgets/button.md:607 | M | button shows focus only for its explicit matching focus identity | Focus | focus identity matching |
| widgets/button.md:608 | M | button exposes transient isPressed and isHovered only to style rendering | Pointer | Includes isHovered, which is pointer-derived hover. |
| widgets/button.md:609 | M | button requests pointer-move input only through a hover consumer in its subtree | Pointer | Pointer-move request/subscription behaviour. |
| widgets/button.md:610 | M | button hover underline clears when the graph clears its hover target on focus loss | Pointer | caps focus+pointer; latest-landing -> Pointer. Hover target lifecycle is pointer state (mouse table move). |
| widgets/button.md:611 | M | default action fires on Return when the focused responder does not consume it | Focus | Return key routing |
| widgets/button.md:612 | M | cancel action fires on Esc when no press is pending and the focused responder does not consume it | Focus | Esc key routing |
| widgets/button.md:613 | M | focused and pressed button applies the pressed trade to its focused look | Focus | focused appearance with pressed state |
| widgets/form.md:1235 | M | form paints the cursor glyph and the bold focus label on the focused row only | Focus | focused-row cursor and label |
| widgets/form.md:1236 | M | form draws the cursor only while focused | Focus | focus-gated cursor |
| widgets/form.md:1237 | M | form draws no cursor and no bold label while unfocused | Focus | unfocused appearance |
| widgets/form.md:1238 | M | form writes a field value only through its binding | Focus | BORDERLINE -> Focus. Field values are written by keys (Left/Right, Enter/Space, editing); the binding-only rule is observable from the first key. |
| widgets/form.md:1239 | M | form derives its hovered row from graph-owned hover, requests move input for it, and changes no value on move | Pointer | Hover derivation and move-input request. |
| widgets/form.md:1243 | M | focused enum row paints its value between secondary arrows, as the number row does | Focus | focused appearance |
| widgets/form.md:1248 | M | number value paints primary and shows its arrows on every number row, focused or not | Focus | asserts across focus states |
| widgets/form.md:1249 | M | number arrows paint secondary and stay in place around the value | Focus | focused number field appearance |
| widgets/form.md:1250 | M | select row opens Picker's menu below its row, with the cursor on the chosen option | Focus | opening via enter or space key |
| widgets/form.md:1251 | M | multi row opens MultiPicker's menu below its row, with a checkbox per choice | Focus | opening via enter or space key |
| widgets/form.md:1252 | ADD | picked radio and checked box paint accent; unpicked radio paints secondary | Focus | UNMARKED ADD. Fixture is "Select dropdown open / Multi dropdown open"; the open flag is NodeState set only by Enter/Space (or click), so an open dropdown first exists at Focus. |
| widgets/form.md:1253 | ADD | dropdown choices indent four cells under their field | Focus | UNMARKED ADD. Fixture is "Select dropdown open"; needs an open dropdown (Enter/Space). |
| widgets/form.md:1254 | M | ASCII cursor is > and number arrows are < and > | Focus | focused cursor under ASCII |
| widgets/form.md:1255 | ADD | ASCII checkbox and radio marks are [x] [ ] and (*) ( ) | Focus | UNMARKED ADD. Fixtures are "Select dropdown open, ASCII" and "Multi dropdown open, ASCII"; need an open dropdown. |
| widgets/form.md:1258 | M | focused failing field keeps the cursor and paints its label bold error | Focus | focused appearance |
| widgets/form.md:1279 | ADD | form draws the visible rows of a partly visible field at the viewport edge, with no mark | Scroll | UNMARKED ADD. Fixture "Overflow, stacked" is at offset 3 with the cursor on Theme; non-zero NodeState offset needs cursor movement plus chase. |
| widgets/form.md:1280 | M | form chase changes the offset by the fewest rows that show the whole field | Scroll | caps focus+scroll; latest-landing -> Scroll. Chase is reveal-on-focus writing the form offset |
| widgets/form.md:1282 | M | form scrolls content taller than its proposed height inside the window | Scroll | BORDERLINE -> Scroll. The Overflow 40x4 fixture is at offset 2 with the cursor on Theme; the offset is NodeState and non-zero only after cursor movement plus chase. |
| widgets/form.md:1283 | M | up on the first row and down on the last row are not consumed | Focus | key routing at bounds |
| widgets/form.md:1284 | M | enter or space on a select or multi row opens Picker's menu | Focus | Enter and Space key routing |
| widgets/form.md:1285 | M | keys while a dropdown is open are handled by Picker's menu | Focus | key routing to open menu |
| widgets/form.md:1286 | M | focus loss closes an open dropdown without committing | Focus | focus loss |
| widgets/form.md:1287 | M | clicking a row sets the cursor and closes a dropdown open on another row | Pointer | BORDERLINE (focus) resolved: pointer is the trigger, so Pointer (latest anyway). |
| widgets/form.md:1288 | M | clicks in an open dropdown are handled by Picker's menu | Pointer | Mouse routing into an open menu. |
| widgets/form.md:1289 | ADD | form height is the content rows plus the rows of an open dropdown | Focus | UNMARKED ADD. Height grows by the rows of an OPEN dropdown; opening is Enter/Space. |
| widgets/form.md:1290 | M | wheel scrolls the viewport without moving the cursor | Scroll | caps pointer+scroll; latest-landing -> Scroll. Wheel changes the form offset |
| widgets/form.md:1291 | M | form leaves clicks and drags on its scrollbar unconsumed | Pointer | Negative click/drag assertion on scrollbar. |
| widgets/form.md:1292 | M | form cursor starts on the first row and keeps its row across focus changes | Focus | cursor across focus changes |
| widgets/form.md:1293 | M | form ends text editing on focus loss | Focus | focus loss |
| widgets/image.md:394 | M | image takes no focus, keys or pointer input in 1.0; apps wrap it in a Button | Pointer | caps focus+pointer; latest-landing -> Pointer. Explicit pointer-input negative assertion. |
| widgets/key-legend.md:261 | ADD | legend shows all five entries at 60 columns | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/key-legend.md:262 | ADD | plain legend keys are bold secondary and descriptions are secondary | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/key-legend.md:263 | ADD | keycaps legend fills each key on a keycap | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/key-legend.md:264 | ADD | narrow legend drops move and search at 40 columns | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/key-legend.md:265 | ADD | narrow legend drops whole entries lowest priority first | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/key-legend.md:266 | ADD | legend at 20 columns keeps only change and close | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/key-legend.md:267 | ADD | legend never cuts an entry in half | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/key-legend.md:268 | ADD | legend drops equal-priority entries as a unit | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/key-legend.md:269 | ADD | legend draws nothing below 20 cells | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/key-legend.md:270 | ADD | legend entries are one row and drop whole by priority instead of wrapping or truncating | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/key-legend.md:271 | ADD | NO_COLOR legend keys stay bold with no brackets or reverse video | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/key-legend.md:272 | ADD | over-maximum legend keeps its ideal width and leading alignment | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/key-legend.md:273 | ADD | ascii legend spells keys out and drops search at 60 columns | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/key-legend.md:274 | ADD | ascii legend separates entries with a pipe | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/key-legend.md:275 | ADD | NO_COLOR legend falls back to the plain look for keycaps | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/key-legend.md:276 | M | legend entries come from the focused responder's bindings | Focus | focused responder bindings (KeyLegend) |
| widgets/key-legend.md:277 | M | legend takes no focus and consumes no keys | Focus | negative focus and key assertion |
| widgets/key-legend.md:278 | ADD | light sixteen colour legend falls back to the plain look for keycaps | Focus | UNMARKED ADD. KeyLegend() takes no arguments: its entries exist only as the focused responder chain's declared key bindings (key-legend.md API, state model: bindings; slice 04), so no legend with entries can render before Focus. (If tests may inject a bindings environment value without Focus, this row stays plain.) |
| widgets/labeled-content.md:379 | M | labeled content holds no node state and lets every key and pointer event bubble | Pointer | caps focus+pointer; latest-landing -> Pointer. Pointer events bubbling is a Pointer routing assertion. |
| widgets/list.md:322 | M | arrow selection auto-commits through the binding without enter | Focus | Down key routing |
| widgets/list.md:323 | M | down with no selection selects the first visible selectable row | Focus | Down key routing |
| widgets/list.md:324 | M | selection traversal skips section headers by construction | Focus | Down key traversal |
| widgets/list.md:325 | M | selection stays visible when moved past the viewport edge | Scroll | caps focus+scroll; latest-landing -> Scroll. Key-driven selection move scrolls the viewport to keep it visible |
| widgets/list.md:326 | M | wheel scrolling moves viewport without changing selection | Scroll | caps pointer+scroll; latest-landing -> Scroll. Wheel changes NodeState scroll offset |
| widgets/list.md:327 | M | boundary wheel events pass to ancestors unconsumed | Scroll | caps pointer+scroll; latest-landing -> Scroll. Boundary wheel bubbling is interactive scroll routing |
| widgets/list.md:329 | M | collapsing the selected rows section hides selection without mutating the binding | Focus | Left key routing |
| widgets/list.md:330 | M | arrows from a hidden selection move to the nearest visible selectable row | Focus | Down key routing |
| widgets/list.md:331 | M | left collapses and right expands the selections section via its binding | Focus | Left and Right key routing |
| widgets/list.md:332 | M | re-expansion renders the preserved selection without auto-scrolling | Scroll | Negative assertion: reveal must not fire; only meaningful once reveal/scroll-to-selection exists |
| widgets/list.md:333 | M | scroll offset clamps when app shrinks data | Scroll | BORDERLINE -> Scroll. List offset is NodeState; the clamp is only observable once input has made it non-zero. |
| widgets/list.md:335 | M | absent selection binding reserves no gutter and arrows scroll | Scroll | caps focus+scroll; latest-landing -> Scroll. Arrow keys scroll the list when no selection binding exists |
| widgets/list.md:336 | M | enter activates the selected element | Focus | Enter key routing |
| widgets/list.md:337 | M | double click selects then activates | Pointer | Mouse double-click. |
| widgets/list.md:338 | M | click on a data row selects it through the binding | Pointer | Mouse click. |
| widgets/list.md:339 | M | click on a collapsible header toggles expansion through its binding | Pointer | Mouse click on header. |
| widgets/list.md:342 | M | unfocused selection renders the inactive tint | Focus | focus-dependent selection style |
| widgets/list.md:347 | M | selection bar is accent when focused and secondary when unfocused | Focus | focus-dependent bar style |
| widgets/list.md:349 | ADD | partly visible items draw their visible rows at the top and bottom edges without a mark | Scroll | UNMARKED ADD. "states: wrapped" is at offset 2 rows (first item shows only its last row); a non-zero NodeState offset is only reachable by scroll input or reveal. |
| widgets/list.md:350 | M | scroll offset thumb and paging count rows not items | Scroll | caps focus+scroll; latest-landing -> Scroll. Paging moves the offset by rows; the thumb clause alone is geometry |
| widgets/list.md:351 | M | reveal scrolls the fewest rows that show the whole selected item | Scroll | caps focus+scroll; latest-landing -> Scroll. Reveal-on-selection writes the offset |
| widgets/list.md:352 | M | item taller than the viewport top-aligns when revealed | Scroll | BORDERLINE (focus) resolved: reveal trigger is irrelevant; offset change makes it Scroll either way. |
| widgets/list.md:353 | M | width change re-measures item heights and clamps the offset | Scroll | BORDERLINE -> Scroll. Re-measure is layout, but the offset clamp needs a prior non-zero NodeState offset. |
| widgets/list.md:356 | M | page down moves selection to the item one viewport of rows below | Focus | EXCEPTION: rule gives Scroll (focus+scroll). The assertion is only the selection TARGET: the item containing the row V rows below the selected item's first row, with V the static viewport height. Neither the offset nor input scrolling enters it; the offset effect is covered by list.md:351 (reveal) and list.md:350 (paging counts rows). Testable at Focus. |
| widgets/list.md:359 | M | row under the pointer takes the hover fill; a selected row keeps selection.fill under the pointer | Pointer | Hover state from pointer position. |
| widgets/list.md:360 | M | rows request pointer motion only while the list is live in the graph | Pointer | Pointer-motion request lifecycle. |
| widgets/list.md:361 | M | .rowHover(.disabled) removes the hover fill and the motion request | Pointer | Hover and motion-request disable. |
| widgets/list.md:362 | M | pointer motion moves the derived hovered row without changing selection or scroll offset | Pointer | Pointer move event handling. |
| widgets/list.md:363 | M | the hovered row clears on focus loss and when motion tracking stops | Pointer | caps focus+pointer; latest-landing -> Pointer. Hover state lifecycle. |
| widgets/list.md:364 | M | slots, NO_COLOR and 16-colour show hover as an underline on the row label | Pointer | Hover degradation rendering requires a hover state. |
| widgets/markdown.md:506 | M | markdown takes no focus, keys or pointer input | Pointer | caps focus+pointer; latest-landing -> Pointer. Explicit pointer-input negative assertion. |
| widgets/markdown.md:515 | M | markdown does not reveal streamed source in 1.0 | Clock | BORDERLINE -> Clock. A negative assertion about time-driven reveal: it needs the clock machinery to advance time and show nothing progressive. (The immediate re-render itself is covered by markdown.md:514, plain.) |
| widgets/multi-picker.md:553 | M | multipicker menu Space toggles the cursor option and keeps the list open | Focus | Space key routing |
| widgets/multi-picker.md:554 | M | multipicker menu Enter bubbles in place | Focus | Enter key routing |
| widgets/multi-picker.md:555 | M | multipicker menu Enter never toggles the cursor option | Focus | Enter key routing |
| widgets/multi-picker.md:556 | M | multipicker menu digit key toggles the Nth option and keeps the list open | Focus | digit key routing |
| widgets/multi-picker.md:557 | M | multipicker menu digit beyond the row count bubbles | Focus | digit key bubbling |
| widgets/multi-picker.md:559 | M | multipicker menu click toggles the option and keeps the list open | Pointer | Mouse click on option row. |
| widgets/multi-picker.md:560 | M | multipicker menu wheel moves the cursor and is consumed at list edges | Pointer | BORDERLINE (scroll) -> Pointer. The wheel moves the cursor, not the offset, and the wheel is always consumed (never bubbles), so no Scroll machinery is asserted. |
| widgets/multi-picker.md:561 | M | multipicker menu paste reaches the draft only while editing | Focus | paste input routed through focus |
| widgets/multi-picker.md:562 | M | multipicker draws no hover and requests no pointer motion | Pointer | Negative pointer-motion/hover assertion. |
| widgets/multi-picker.md:566 | M | multipicker menu scrolls in rows under a fixed height | Scroll | BORDERLINE -> Scroll. Menu scroll offset is NodeState; "scrolls in rows" (40x3, partly visible option) needs a non-zero offset. |
| widgets/multi-picker.md:573 | M | multipicker Other row starts editing on Space and a click | Pointer | caps focus+pointer; latest-landing -> Pointer. Mouse click on custom row. |
| widgets/multi-picker.md:574 | M | multipicker custom draft Enter adds the accepted value to the binding | Focus | Enter key routing while editing |
| widgets/multi-picker.md:575 | M | multipicker custom draft rejected by customOption keeps editing | Focus | Enter key routing while editing |
| widgets/multi-picker.md:577 | M | multipicker never inserts a duplicate typed value | Focus | Enter key routing while editing |
| widgets/multi-picker.md:578 | ADD | multipicker unchecking a typed value removes it from the binding and its row | Focus | UNMARKED ADD. Unchecking a typed value is a toggle (Space or digit key) on the typed row. |
| widgets/multi-picker.md:579 | M | multipicker draft line stays one row and scrolls around the caret | Focus | BORDERLINE (scroll) -> Focus. The one-row draft line follows the caret while editing; it is editing machinery (keys), with no viewport, wheel, bubbling or indicator involved. |
| widgets/multi-picker.md:580 | M | multipicker cursor stays on the unchecked Other row after an accepted draft | Focus | Enter key routing and cursor |
| widgets/multi-picker.md:585 | M | multipicker radio group Space toggles the cursor chip | Focus | Space key routing |
| widgets/multi-picker.md:586 | M | multipicker radio group Enter bubbles | Focus | Enter key routing |
| widgets/multi-picker.md:587 | M | multipicker radio group Left and Right move the cursor and wrap across rows | Focus | Left and Right key routing |
| widgets/multi-picker.md:588 | M | multipicker radio group click toggles the chip | Pointer | Mouse click on chip. |
| widgets/multi-picker.md:591 | M | multipicker radio group leaves Up and Down unconsumed | Focus | Up and Down key routing |
| widgets/multi-picker.md:596 | ADD | multipicker host row draws the title as the host's row label and no title row in the open list | Focus | UNMARKED ADD. Same as picker.md:1386 for MultiPicker host row. |
| widgets/multi-picker.md:597 | M | multipicker host row Enter and Space open the list below the row | Focus | Enter and Space key routing |
| widgets/multi-picker.md:598 | M | multipicker host row Space toggles and keeps the list open | Focus | Space key routing |
| widgets/multi-picker.md:599 | M | multipicker host row Enter closes the list without writing | Focus | Enter key routing |
| widgets/multi-picker.md:600 | M | multipicker host row Escape closes the list and toggles already written stay | Focus | Escape key routing |
| widgets/multi-picker.md:601 | M | multipicker host row focus loss closes the list | Focus | focus loss |
| widgets/multi-picker.md:606 | M | multipicker host row digit key toggles the Nth option and keeps the list open | Focus | digit key routing |
| widgets/navigation-split-view.md:349 | ADD | tier change moves focus to a rendered column without mutating business bindings | Focus | UNMARKED ADD. Tier change moves focus to a rendered column (focus model). Doc has no participation entry. |
| widgets/navigation-split-view.md:350 | ADD | container consumes no keys and installs no pointer handlers | Pointer | UNMARKED ADD. Negative over the key table and mouse table; the pointer half needs hit-testing machinery, so the later capability (Pointer). |
| widgets/navigation-split-view.md:351 | ADD | divider drag changes the side pane on its first press | Pointer | UNMARKED ADD. Divider drag first press (mouse table: leading divider). |
| widgets/navigation-split-view.md:352 | ADD | sidebar selection dims to inactive when its column loses focus | Focus | UNMARKED ADD. Sidebar selection tint swaps to inactive on focus loss (focused appearance). |
| widgets/outline.md:470 | M | scrolls itself without a ScrollView wrapper | Scroll | BORDERLINE -> Scroll. The Scrolled fixture is at offset 7 (selection kept visible); the claim is only verifiable with a non-zero NodeState offset. |
| widgets/outline.md:473 | ADD | thumb length and row follow the scrolled formulas | Scroll | UNMARKED ADD. "thumb ... row follow the scrolled formulas": Scrolled fixture is at offset 7 (NodeState), so the thumb row needs scroll/reveal. |
| widgets/outline.md:488 | M | uses the tree keys and mouse in path mode | Pointer | caps focus+pointer; latest-landing -> Pointer. Mouse behaviour in path mode. |
| widgets/outline.md:492 | M | moves selection with the up and down arrows | Focus | arrow key routing |
| widgets/outline.md:493 | M | saturates up and down at the last and first row and keeps them consumed | Focus | arrow key routing and consumption |
| widgets/outline.md:494 | M | selects the first visible row on down when nothing is selected | Focus | Down key routing |
| widgets/outline.md:495 | M | moves selection with Home, End, PgUp and PgDn | Focus | EXCEPTION: rule gives Scroll (focus+scroll). Home/End/PgUp/PgDn only move the selection (PgUp/PgDn by V static viewport rows); the offset effect is covered by outline reveal (gap) and outline.md:470. Testable at Focus. |
| widgets/outline.md:496 | M | expands, collapses and moves selection with the left and right arrows | Focus | Left and Right key routing |
| widgets/outline.md:497 | M | toggles a branch on Space and lets Space on a leaf bubble | Focus | Space key routing |
| widgets/outline.md:498 | M | calls onActivate with the selected node on Enter | Focus | Enter key routing |
| widgets/outline.md:499 | M | selects a row on click and toggles a branch on expander click | Pointer | Mouse click and expander click. |
| widgets/outline.md:500 | M | selects the row and calls onActivate on double-click | Pointer | Mouse double-click. |
| widgets/outline.md:501 | M | scrolls the rows on wheel-up and wheel-down without moving the selection | Scroll | caps pointer+scroll; latest-landing -> Scroll. Wheel changes NodeState scroll offset |
| widgets/outline.md:502 | M | leaves a wheel event at the scroll boundary unconsumed | Scroll | caps pointer+scroll; latest-landing -> Scroll. Boundary wheel routing is interactive scroll |
| widgets/picker.md:1284 | M | picker first enabled cycle from an absent value selects the first supplied option | Focus | Right key routing |
| widgets/picker.md:1285 | M | picker advances on focused right and down keys | Focus | focused key routing |
| widgets/picker.md:1286 | M | picker moves backward on focused left and up keys | Focus | focused key routing |
| widgets/picker.md:1287 | M | picker bubbles an unavailable endpoint cycle without changing selection | Focus | key bubbling at endpoints |
| widgets/picker.md:1288 | M | picker focuses before a value-slot click advances selection | Pointer | caps focus+pointer; latest-landing -> Pointer. Click-to-focus then click advance (mouse table). |
| widgets/picker.md:1289 | M | picker leaves a last-option value-slot click unconsumed | Pointer | Negative click consumption. |
| widgets/picker.md:1290 | M | disabled picker is unfocusable and leaves input unconsumed | Pointer | caps focus+pointer; latest-landing -> Pointer. Mouse table value-slot click on disabled picker is unconsumed. |
| widgets/picker.md:1296 | M | picker draws no hover and requests no pointer motion in any presentation | Pointer | Negative hover/pointer-motion assertion. |
| widgets/picker.md:1313 | M | picker radio group Right and Left advance in order and wrap across rows | Focus | Left and Right key routing |
| widgets/picker.md:1314 | M | picker radio group leaves Up and Down unconsumed | Focus | Up and Down key routing |
| widgets/picker.md:1315 | M | picker radio group click on a chip sets selection and consumes the click | Pointer | Mouse click on chip. |
| widgets/picker.md:1316 | M | picker radio group shows the cursor prefix only while focused | Focus | focus-gated cursor |
| widgets/picker.md:1321 | M | picker menu lists options in place with a cursor separate from the chosen marker | Focus | menu cursor shown with focus |
| widgets/picker.md:1322 | M | picker menu clamps Up and Down at the list edges without wrapping | Focus | Up and Down key routing |
| widgets/picker.md:1323 | M | picker menu Enter commits the cursor option through the binding | Focus | Enter key routing |
| widgets/picker.md:1325 | M | picker menu wheel moves the cursor and is consumed at list edges | Pointer | BORDERLINE (scroll) -> Pointer. Same as multi-picker.md:560. |
| widgets/picker.md:1326 | M | picker menu paste while editing inserts into the draft with line breaks as spaces | Focus | paste input routed through focus |
| widgets/picker.md:1327 | M | picker menu click on an option row moves the cursor then commits it | Pointer | Mouse click on option row. |
| widgets/picker.md:1333 | M | picker menu scrolls in rows and shows partial items at both edges | Scroll | BORDERLINE -> Scroll. Partial items at BOTH edges needs a non-zero NodeState menu offset. |
| widgets/picker.md:1334 | M | picker menu reveals the whole cursor item by the fewest rows | Scroll | caps focus+scroll; latest-landing -> Scroll. Reveal-on-cursor-move writes the menu offset |
| widgets/picker.md:1335 | M | picker menu PgUp and PgDn move the cursor by viewport rows | Focus | EXCEPTION: rule gives Scroll (focus+scroll). PgUp/PgDn move the CURSOR by the options spanning V viewport rows (V static from layout); the offset effect is covered by picker.md:1334. Testable at Focus. |
| widgets/picker.md:1341 | M | picker menu Enter on the custom row starts editing | Focus | Enter key routing |
| widgets/picker.md:1342 | M | picker menu editing keys edit the draft and Enter commits it through customOption | Focus | editing key routing |
| widgets/picker.md:1343 | M | picker menu keeps editing when customOption rejects the draft | Focus | Enter key routing while editing |
| widgets/picker.md:1344 | M | picker menu Escape ends editing and clears the draft while a committed value stays | Focus | Escape key routing |
| widgets/picker.md:1345 | M | picker menu keeps the custom row chosen with its committed value after Enter | Focus | Enter key routing |
| widgets/picker.md:1346 | M | picker menu draft line stays one row and scrolls around the caret | Focus | BORDERLINE (scroll) -> Focus. Same as multi-picker.md:579. |
| widgets/picker.md:1358 | M | picker segmented active segment draws solid(accent) with no underline in colour tiers and underlines only under NO_COLOR while focused | Focus | focused appearance |
| widgets/picker.md:1359 | M | picker segmented unselected segment labels brighten from secondary to primary while the picker is focused | Focus | focused appearance |
| widgets/picker.md:1362 | M | picker segmented Right and Left wrap and are consumed | Focus | Left and Right key routing |
| widgets/picker.md:1363 | M | picker segmented click on a segment sets selection and consumes the click | Pointer | Mouse click on segment. |
| widgets/picker.md:1367 | M | picker menu digit key commits the Nth option | Focus | digit key routing |
| widgets/picker.md:1368 | M | picker menu digit beyond the option count bubbles | Focus | digit key bubbling |
| widgets/picker.md:1370 | M | picker menu digit is typed text while editing the custom row | Focus | typing keys while editing |
| widgets/picker.md:1380 | M | picker host row Enter and Space open the list below the row | Focus | Enter and Space key routing |
| widgets/picker.md:1381 | M | picker host row Up, Down, Left, and Right bubble while closed | Focus | arrow key bubbling |
| widgets/picker.md:1382 | M | picker host row Enter and Space commit the cursor option and close | Focus | Enter and Space key routing |
| widgets/picker.md:1383 | M | picker host row Escape closes the list without committing | Focus | Escape key routing |
| widgets/picker.md:1384 | M | picker host row focus loss closes the list without committing | Focus | focus loss |
| widgets/picker.md:1385 | M | picker host row digit key commits the Nth option and closes | Focus | digit key routing |
| widgets/picker.md:1386 | ADD | picker host row draws the title as the host's row label and no title row in the open list | Focus | UNMARKED ADD. Half of the assertion ("no title row in the open list") needs the host row opened with Enter/Space. |
| widgets/progress-view.md:477 | M | indeterminate label wraps beside the spinner | none | BORDERLINE -> none. Label wrap beside a fixed-width spinner column is layout at one instant; the frame never changes the label column. Assumes tests can supply a clock instant through the environment key before Clock lands (see Disagreements D9). |
| widgets/progress-view.md:481 | M | indeterminate label starts two cells in for every frame set | Clock | Must hold across every frame of every set as the spinner turns; frames are selected from the supplied clock |
| widgets/progress-view.md:487 | M | built-in spinner sets run at their own intervals | Clock | Frame interval is a time property of each set |
| widgets/progress-view.md:489 | M | spinner frame derives from the supplied clock and stores no state | Clock | Frame is (now / interval) mod frames.count from the injected clock; needs Clock machinery |
| widgets/progress-view.md:490 | M | indeterminate view declares a tick requirement at its frame set's interval | Clock | Tick requirement declaration is the Clock machinery's input |
| widgets/progress-view.md:491 | M | determinate view declares no tick requirement | Clock | Negative assertion about tick requirements; only meaningful once tick declaration exists |
| widgets/progress-view.md:492 | M | nerd font set drawn as orbit declares orbit's interval | Clock | Tick requirement uses the drawn set's interval |
| widgets/scroll-view.md:510 | M | vertical offset indicator and paging count rows not items | Scroll | caps focus+scroll; latest-landing -> Scroll. PgUp and PgDn change the offset by viewport rows; paging is interactive offset change |
| widgets/scroll-view.md:512 | M | reveal scrolls the fewest rows that show a whole item and top-aligns a taller one | Scroll | BORDERLINE (focus) resolved: reveal is Scroll whatever triggers it. |
| widgets/scroll-view.md:516 | M | focused arrow keys move one cell on their enabled axis | Scroll | caps focus+scroll; latest-landing -> Scroll. Arrow keys change the offset; needs key-driven scroll |
| widgets/scroll-view.md:517 | M | page home and end keys clamp to the viewport bounds | Scroll | caps focus+scroll; latest-landing -> Scroll. Paging and Home/End change the offset by key |
| widgets/scroll-view.md:518 | M | keyboard input bubbles from a focusable scroll view at its boundary | Scroll | caps focus+scroll; latest-landing -> Scroll. Boundary bubbling to enclosing viewport is interactive routing |
| widgets/scroll-view.md:520 | M | focused scroll view delegates a foreground-only box border while retaining key ownership and its edge-riding indicator | Focus | focused appearance and key ownership |
| widgets/scroll-view.md:521 | M | focused fitting scroll view shows no local treatment without an indicator | Focus | focused appearance |
| widgets/scroll-view.md:522 | M | focused viewport paints indicator thumbs in focus (bold default foreground) without restyling content | Focus | focused appearance |
| widgets/scroll-view.md:523 | M | owned focus identity registers and withdraws as layout settles | Focus | focus registration |
| widgets/scroll-view.md:524 | M | owned focus identity requires an offset binding | Focus | focus eligibility |
| widgets/scroll-view.md:525 | M | key repeats scroll exactly like presses | Scroll | caps focus+scroll; latest-landing -> Scroll. Scroll keys must move the offset; repeat only matters once keys scroll |
| widgets/scroll-view.md:526 | M | unconsumed scroll keys bubble to a focus-within ancestor viewport | Scroll | caps focus+scroll; latest-landing -> Scroll. Unconsumed scroll keys reaching an ancestor viewport is boundary bubbling |
| widgets/scroll-view.md:530 | M | ascii degradation preserves scroll geometry and boundary routing | Scroll | BORDERLINE (focus) resolved: the rule is about scroll geometry and wheel/key boundary routing; Scroll either way. |
| widgets/scroll-view.md:531 | M | scroll view exposes no zoom or smooth animation transition | Clock | BORDERLINE (clock) -> Clock. Offsets are written synchronously by input (Scroll), but "no zoom or smooth animation transition" is a negative assertion about motion over time; it needs the Clock machinery to prove no transition or tick requirement exists. Latest-landing rule gives Clock; not an exception. |
| widgets/scroll-view.md:538 | M | unbound scroll view stays at the origin | Scroll | BORDERLINE -> Scroll. The claim bites only when key or wheel input reaches an unbound viewport and the offset is held at the origin (negative assertion, needs Scroll input). |
| widgets/scroll-view.md:539 | M | wheel moves one row or column through the offset binding | Scroll | caps pointer+scroll; latest-landing -> Scroll. Wheel changes the offset |
| widgets/scroll-view.md:540 | M | wheel at a boundary or without a binding bubbles to an enclosing viewport | Scroll | caps pointer+scroll; latest-landing -> Scroll. Wheel boundary bubbling to enclosing viewport |
| widgets/scroll-view.md:541 | M | wheel on an axis the viewport does not scroll bubbles | Scroll | caps pointer+scroll; latest-landing -> Scroll. Wheel routing decision per axis; bubbling is interactive |
| widgets/scroll-view.md:542 | M | clicks and drags on indicators and the corner return ignored | Pointer | Negative click/drag assertion on indicators and corner. |
| widgets/scroll-view.md:543 | M | focus moving into hidden content reveals it through the offset binding | Scroll | caps focus+scroll; latest-landing -> Scroll. Reveal-on-focus writes the offset |
| widgets/section.md:186 | M | header is not focusable and not selectable | Focus | negative focus assertion |
| widgets/section.md:191 | M | click on a collapsible header toggles expansion through the binding | Pointer | Mouse click on header. |
| widgets/section.md:192 | M | click on a noninteractive header is not consumed | Pointer | Negative click consumption. |
| widgets/section.md:193 | M | section forwards row focus input and bindings without interception | Pointer | caps focus+pointer; latest-landing -> Pointer. Forwarding of pointer input to grouped rows (mouse table). |
| widgets/split-view.md:632 | M | split view restores a hidden focused descendant only when focus remains clear | Focus | focus return |
| widgets/split-view.md:633 | M | split view moves focus to the nearest visible pane when collapsing the focused pane | Focus | focus removal handling |
| widgets/split-view.md:634 | M | focused divider arrow keys move the boundary on first press with flexible slack | Focus | arrow key routing to focused divider |
| widgets/split-view.md:635 | M | horizontal divider handle arrow keys resize only its adjacent controlled pane pair | Focus | arrow key routing |
| widgets/split-view.md:636 | M | vertical divider handle arrow keys resize only its adjacent controlled pane pair | Focus | arrow key routing |
| widgets/split-view.md:637 | M | split view leaves tab and escape available to application routing | Focus | Tab and Esc key routing |
| widgets/split-view.md:638 | M | dragging a divider updates adjacent bound sizes with integer clamping | Pointer | Drag gesture. |
| widgets/split-view.md:639 | M | active split drag survives reconciliation for a stable pane pair | Pointer | Pointer drag state (state model: pointer drag). |
| widgets/split-view.md:640 | M | split view cancels a stale drag when its pane pair disappears | Pointer | Pointer drag cancellation (mouse table). |
| widgets/split-view.md:648 | M | split view transposes divider hit geometry for vertical axis | Pointer | Asserts hit geometry of dividers. |
| widgets/split-view.md:649 | M | focused divider styling overlays only a bold focus foreground with no background | Focus | focused appearance |
| widgets/split-view.md:650 | M | split view moves a focused divider five cells with shift arrow keys | Focus | Shift-arrow key routing |
| widgets/split-view.md:651 | M | split view resets a focused divider pair to defaultIdeal with equals | Focus | = key routing |
| widgets/split-view.md:652 | M | split view resets a divider pair to defaultIdeal on double-click | Pointer | Mouse double-click. |
| widgets/split-view.md:653 | M | divider grab zone hit-tests one cell to each side without drawing extra cells | Pointer | Hit testing of grab zone. |
| widgets/split-view.md:660 | M | focused divider draws the heavy line in the focus style | Focus | focused appearance |
| widgets/split-view.md:661 | M | focused divider junctions render heavy junction glyphs | Focus | focused appearance |
| widgets/split-view.md:662 | M | ascii fallback draws plus at junctions and bolds a focused divider | Focus | focused appearance under ASCII |
| widgets/stepper.md:371 | M | stepper increments its binding from an interior value | Focus | Up key routing |
| widgets/stepper.md:372 | M | stepper decrements its binding from an interior value | Focus | Down key routing |
| widgets/stepper.md:373 | M | stepper leaves an increment key unconsumed at maximum | Focus | key consumption |
| widgets/stepper.md:374 | M | stepper leaves a decrement key unconsumed at minimum | Focus | key consumption |
| widgets/stepper.md:375 | M | stepper clamps a non-divisible final increment exactly to maximum | Focus | Up key routing |
| widgets/stepper.md:376 | M | stepper clamps a non-divisible final decrement exactly to minimum | Focus | Down key routing |
| widgets/stepper.md:378 | M | stepper clamps an out-of-range value through its binding on user activation | Focus | Up or Down key routing |
| widgets/stepper.md:379 | M | stepper applies a positive non-unit stride through its binding | Focus | Up key routing |
| widgets/stepper.md:381 | M | stepper keeps both arrows visible while unfocused | Focus | unfocused appearance |
| widgets/stepper.md:382 | M | stepper draws an arrow at its limit in the disabled role and keeps its place | Focus | focused-at-limit appearance |
| widgets/stepper.md:384 | M | stepper marks focus with the host row's cursor and focus-role label, not the arrows | Focus | focus appearance |
| widgets/stepper.md:385 | M | stepper focuses before increment-arrow activation | Pointer | caps focus+pointer; latest-landing -> Pointer. Click-to-focus on arrow click (mouse table). |
| widgets/stepper.md:386 | M | stepper leaves endpoint-arrow clicks unconsumed | Pointer | Negative click consumption at endpoints. |
| widgets/stepper.md:387 | M | disabled stepper renders every part in the disabled role and leaves keys and clicks unconsumed | Pointer | caps focus+pointer; latest-landing -> Pointer. Negative click consumption when disabled. |
| widgets/tab-view.md:436 | M | left on the first tab wraps the selection to the last tab | Focus | Left key routing |
| widgets/tab-view.md:437 | M | right on the last tab wraps the selection to the first tab | Focus | Right key routing |
| widgets/tab-view.md:438 | M | left and right write the selection only through the binding | Focus | Left and Right key routing |
| widgets/tab-view.md:440 | M | clicking a tab chip writes its value through the binding | Pointer | Mouse click on chip. |
| widgets/tab-view.md:441 | M | clicking the active tab chip leaves the selection unchanged | Pointer | Mouse click on active chip. |
| widgets/tab-view.md:442 | M | a click outside a tab chip has no effect | Pointer | Click hit testing outside chips. |
| widgets/tab-view.md:443 | M | move input is requested only while a hover consumer exists in the subtree; with none, move events are not delivered | Pointer | Pointer-move request and delivery. |
| widgets/tab-view.md:444 | M | move events draw no hover state | Pointer | Negative hover assertion from move events. |
| widgets/tab-view.md:445 | M | focused tab view draws the focus cursor on the bar row only | Focus | focus cursor |
| widgets/tab-view.md:446 | M | nerd font draws the cursor mark as U+F054 | Focus | focus cursor glyph |
| widgets/tab-view.md:447 | M | unfocused tab view draws a blank cursor and the accent pill | Focus | unfocused appearance |
| widgets/tab-view.md:450 | M | active pill is solid(focus) while the tab view is focused and solid(accent) when it is not | Focus | focus-dependent appearance |
| widgets/table.md:756 | M | selection stays visible when moved past the viewport edge | Scroll | caps focus+scroll; latest-landing -> Scroll. Key-driven selection move scrolls the viewport |
| widgets/table.md:757 | M | successive selection moves separated by graph updates keep selection and scroll offset synchronized | Scroll | caps focus+scroll; latest-landing -> Scroll. Repeated key-driven moves must keep the NodeState offset in step with selection |
| widgets/table.md:758 | M | wheel scrolling moves viewport without changing selection | Scroll | caps pointer+scroll; latest-landing -> Scroll. Wheel changes scroll offset |
| widgets/table.md:759 | M | scroll indicator is output-only and has no drag interaction | Pointer | Negative drag assertion on indicator. |
| widgets/table.md:762 | M | scroll offset clamps when app shrinks data | Scroll | BORDERLINE -> Scroll. Table offset is NodeState; clamp observable only after it is non-zero. |
| widgets/table.md:764 | M | header click cycles the sort entry for that column id through binding | Pointer | Mouse click on header cell. |
| widgets/table.md:767 | M | enter activates the selected element | Focus | Enter key routing |
| widgets/table.md:784 | M | table with focus draws its outer ring in the focus role with the heavy set; focus inside draws it at light weight | Focus | focus appearance |
| widgets/table.md:785 | M | ascii focus renders bold on the bordered ring | Focus | focus appearance under ASCII |
| widgets/table.md:788 | M | multi-select click on a data row replaces the selection set and moves the cursor there | Pointer | Mouse click on data row. |
| widgets/table.md:789 | M | mark gutter click toggles membership and moves the cursor | Pointer | Mouse click on gutter. |
| widgets/table.md:790 | M | double-click runs the click effect, then activates the row, in single and multi-select | Pointer | Mouse double-click. |
| widgets/table.md:791 | M | multi-select arrow keys move the cursor and leave membership unchanged | Focus | arrow key routing |
| widgets/table.md:792 | M | multi-select space toggles the cursor row membership and leaves the cursor in place | Focus | Space key routing |
| widgets/table.md:793 | M | multi-select enter activates the cursor row | Focus | Enter key routing |
| widgets/table.md:794 | ADD | multi-select cursor clamps to the data count and clears when data is empty | Focus | UNMARKED ADD. Cursor is NodeState "nil until a cursor key or click"; a non-nil cursor to clamp or clear needs keys, which land first. |
| widgets/table.md:797 | M | ctrl-up enters header mode only when a sort order binding is set | Focus | Ctrl-Up key routing |
| widgets/table.md:798 | M | space in header mode cycles that column's sort entry through none, ascending, descending, removed | Focus | Space key routing in header mode |
| widgets/table.md:799 | M | left and right clamp the header cursor to the first and last column | Focus | Left and Right key routing |
| widgets/table.md:800 | M | down and escape leave header mode, and focus loss clears the header cursor | Focus | key routing and focus loss |
| widgets/table.md:801 | M | header mode draws the header cursor cell in selection fill and dims the row selection | Focus | header mode keyboard state |
| widgets/table.md:814 | M | bar cell takes accent or secondary and the selection fill when derived; under reverse-video selection fill it draws on the terminal background | Focus | accent or secondary depends on focus |
| widgets/table.md:815 | M | row under the pointer takes the hover fill; a selected row keeps selection.fill under the pointer | Pointer | Hover state from pointer position. |
| widgets/table.md:816 | M | hover and stripes coexist: a hovered striped row shows hover over its stripe | Pointer | Hover state. |
| widgets/table.md:817 | M | rows request pointer motion only while the table is live in the graph | Pointer | Pointer-motion request lifecycle. |
| widgets/table.md:818 | M | .rowHover(.disabled) removes the hover fill and the motion request | Pointer | Hover and motion-request disable. |
| widgets/table.md:819 | M | move event sets the hovered row without changing selection or scroll offset | Pointer | Pointer move event handling. |
| widgets/table.md:820 | M | slots, NO_COLOR and 16-colour show hover as an underline on the row label | Pointer | Hover degradation rendering requires hover state. |
| widgets/table.md:821 | M | scroll offset thumb and paging count rows not data rows | Scroll | caps focus+scroll; latest-landing -> Scroll. Paging moves the offset by rows; the thumb clause alone is geometry |
| widgets/table.md:822 | ADD | partly visible data row draws its visible rows without a mark | Scroll | UNMARKED ADD. Partly visible data row at the top edge needs a non-zero NodeState offset. |
| widgets/text-field.md:444 | M | text field continuously writes printable graphemes through its binding | Focus | printable key routing |
| widgets/text-field.md:445 | M | text field normalizes focused paste input into one single-line binding edit | Focus | focused paste input |
| widgets/text-field.md:446 | M | text field routes software keyboard and dictation characters as ordinary printable input | Focus | printable key routing |
| widgets/text-field.md:447 | M | text field clamps its cursor after the app replaces bound text | Focus | BORDERLINE -> Focus. The caret has no non-initial position until a key (or click) places it; keys land first, so Focus. |
| widgets/text-field.md:448 | M | text field clamps its selection anchor after the app replaces bound text | Focus | selection anchor set by keyboard selection |
| widgets/text-field.md:449 | M | text field replaces whole selected graphemes through its binding | Focus | printable key routing over selection |
| widgets/text-field.md:450 | M | text field never positions caret inside CJK emoji or combining graphemes | Focus | Left key routing |
| widgets/text-field.md:451 | M | text field reveals the hardware caret without inserting an ellipsis into editable text | Focus | BORDERLINE (scroll) -> Focus. Hardware caret exists only while focused; the horizontal reveal offset is derived from caret motion, not from any Scroll capability. |
| widgets/text-field.md:456 | M | text field invokes submit without owning or clearing app text | Focus | Enter key routing |
| widgets/text-field.md:457 | M | text field bubbles Enter when has submit handler is false | Focus | Enter key bubbling |
| widgets/text-field.md:458 | M | text field bubbles Tab and Esc for app focus and dismissal policy | Focus | Tab and Esc key bubbling |
| widgets/text-field.md:459 | M | text field deletes whole graphemes on both sides of the caret | Focus | Backspace and Delete key routing |
| widgets/text-field.md:460 | M | text field maps an enabled input-line click to a grapheme boundary | Pointer | BORDERLINE (focus) resolved: click is the trigger, so Pointer (latest anyway). |
| widgets/text-field.md:461 | M | text field requests a focused enabled hardware cursor at its visible caret boundary | Focus | focus-gated cursor |
| widgets/text-field.md:462 | M | text field leaves disabled bindings and routing untouched | Pointer | caps focus+pointer; latest-landing -> Pointer. Mouse table disabled-click negative assertion; key half is Focus. |
| widgets/toggle.md:454 | M | toggle keeps a parent-forced mobile row as one full-width hit target | Pointer | Asserts the clickable region (hit target); needs hit testing. |
| widgets/toggle.md:459 | M | toggle preserves checkbox geometry for focus and press feedback | Focus | focus feedback |
| widgets/toggle.md:460 | M | disabled toggle is absent from focus and bubbles activation input | Pointer | caps focus+pointer; latest-landing -> Pointer. Mouse table disabled-click bubbling. |
| widgets/toggle.md:461 | M | enter toggles the bound value exactly once across phased and legacy input | Focus | Enter key routing |
| widgets/toggle.md:462 | M | space toggles the bound value exactly once across phased and legacy input | Focus | Space key routing |
| widgets/toggle.md:463 | M | pointer activation focuses before one same-node value inversion | Pointer | caps focus+pointer; latest-landing -> Pointer. Pointer click-to-focus and same-node activation. |
| widgets/toggle.md:464 | M | toggle clears a pending press when a pointer release leaves its node | Pointer | Pointer drag/release semantics. |
| widgets/toggle.md:469 | M | standalone focused toggle marks its label with an underline and keeps its marker colour | Focus | focused appearance |
| widgets/toggle.md:470 | M | focused toggle in a form row shows the row cursor and a bold focus label without an underline | Focus | focused appearance |
| widgets/toggle.md:478 | M | text style keeps the checkbox keyboard, pointer, focus, and disabled contract | Pointer | caps focus+pointer; latest-landing -> Pointer. Explicitly includes pointer contract. |
| widgets/toggle.md:479 | M | a click anywhere on a text-style Form row acts as Enter and inverts the value once | Pointer | BORDERLINE (focus) resolved: click is the trigger, so Pointer (latest anyway). |

### Considered and left in the plain `## Requirements` list

Unmarked rows whose trace names a capability fixture but whose assertion does not need it. If Main disagrees with a line, move the row per its stated reason.

- `widgets/progress-view.md:477, 482, 483, 484, 485, 486, 488`: Frame-set resolution and label column beside a fixed-width spinner are functions of the charset and one clock instant. Assumes the environment clock value (key L1) can be injected by a test before Clock lands (D9). If not, move all seven to Clock.
- `widgets/scroll-view.md:503-509, 511, 513-515, 519, 527-529`: ScrollView offset is a `Binding`; the test sets it, so geometry, clamp, partial-item and reservation rows are static.
- `widgets/outline.md:471, 472, 474, 475, 486`: Use the Scrolled / minimum fixture but assert indicator reservation, highlight width, colours, thumb LENGTH: independent of the non-zero offset (473 moved because it asserts the thumb ROW).
- `widgets/list.md:328, 334, 346, 348, 358; widgets/table.md:761, 780, 783, 795, 796, 802, 813; widgets/section.md:194`: Selection and sort come from bindings (vanished ids, hidden selections, bars and fills), asserted at offset 0 or independent of focus; no input needed.
- `widgets/form.md:1241, 1242, 1244-1247, 1256, 1257, 1259-1265, 1281`: Closed-field values, validation, scrollbar reservation: bindings and layout only.
- `widgets/picker.md:1295, 1324, 1329, 1347, 1379, 1387, 1388; widgets/multi-picker.md:568, 576, 595; widgets/tab-view.md:439, 451; widgets/stepper.md:377, 383; widgets/text-field.md:453; widgets/button.md:567, 568, 590, 594, 614; widgets/split-view.md:629, 643, 647, 654, 658`: Binding-supplied state, closed host rows, static degradation or style resolution; nothing needs focus, pointer, scroll offset or time.

## 2. Gaps

Every `own`/`affects` behaviour and every stated negative behaviour in `participation.jsonl` is either in the "Gaps" table (no existing requirement covers it, DRAFT given) or in "Dropped as covered" (covering requirement named). Draft form is the catalog's: `` `sentence style test name` (trace) ``; traces name sections that exist in the doc (checked against the heading list). `Sub` is the subsection the draft belongs in.

### 2a. Doc-level mismatches from the brief

| doc / capability | resolution |
|---|---|
| border / pointer | gap drafted (hit testing follows wrapped child) |
| divider / focus | junction behaviour covered by border.md:256 + split-view.md:661; "no focus, no state, no events" drafted |
| frame / pointer | gap drafted |
| padding / pointer | gap drafted |
| text-selection / focus+pointer+scroll | gaps listed, no drafts (sketch status), 2b |
| view-that-fits / scroll | gap drafted (candidate ScrollView clamp across a switch); node-state row 312 placed Focus |
| z-stack / pointer | gap drafted |
| content-unavailable-view / focus+pointer | two gaps drafted |
| also found: navigation-split-view | absent from participation.jsonl; its four unmarked rows added to Placement (D5) |

### 2b. `primitives/text-selection.md` (sketch; deferred to the pointer slice): gaps listed, NOT drafted

The doc has no `## Requirements` section; every behaviour below is uncovered.

| capability | behaviour (from participation) |
|---|---|
| focus | keyboard gestures (shift-extended selection, select-all) map to semantic ranges; selection ownership is focus-scoped (open question) |
| focus | copy action is an explicit command routed to a responder; clipboard denial leaves range and highlight valid |
| pointer | pointer gestures (click, double-click word, triple-click line, drag) map through frames, clips and wrapping to semantic text ranges |
| pointer | adjacent SplitView/Grid/Table columns stay independent selection regions even on the same terminal rows |
| pointer | drag capture after the pointer leaves the originating fragment |
| pointer | selection highlight uses selection.fill / selection.inactive and is geometrically correct without colour |
| pointer | Text does not retain state or consume pointer events directly |
| pointer | coexistence with terminal-native selection while mouse tracking is effective |
| scroll | selection maps through scrolling; ScrollView offsets and clipped-away fragments participate in range extension and autoscroll |

### 2c. Gaps with DRAFT requirements

| # | doc | capability | behaviour with no covering requirement | DRAFT | Sub |
|---|---|---|---|---|---|
| G1 | primitives/background | pointer | hit region follows the clip to the primary final bounds | `background hit testing is clipped to the primary child's final bounds` (anatomy: opaque background; primary final bounds and clipped background layer) | Pointer |
| G2 | primitives/badge | pointer | Badge takes no pointer input | `badge takes no pointer input` (primitive: no mouse table) | Pointer |
| G3 | primitives/border | focus | Border holds no focus state; the owning view chooses set and lineStyle | `border holds no focus state and the owning view chooses its set and line style` (focus border: summary; Public API) | Focus |
| G4 | primitives/border | pointer | ring is decorative; hit testing follows the wrapped child's final frame and clip | `border ring is decorative and hit testing follows the wrapped child's final frame and clip` (Decisions: hit testing deferred to Slice 5) | Pointer |
| G5 | primitives/box | focus | joins focus only through explicit .focusable(id) | `box joins focus only through an explicit focusable id` (focus: self focus; state model) | Focus |
| G6 | primitives/box | focus | focus paints only the foreground of border glyphs and title; backgrounds stay transparent; BorderStyle and title position unchanged | `focus paints only the foreground of the ring and title and leaves backgrounds and title position unchanged` (focus: self focus; Decisions) | Focus |
| G7 | primitives/box | focus | Box owns no key routing; a focusable Box gains no press behaviour | `focusable box owns no key routing and gains no press behaviour` (State model; Decisions) | Focus |
| G8 | primitives/box | pointer | Box names no hit region | `box names no hit region` (Decisions: hit testing deferred to Slice 5) | Pointer |
| G9 | primitives/divider | focus+pointer | divider has no focus, no state, no events; handles no pointer events | `divider takes no focus and handles no key or pointer events` (Overview; Blended junctions) | Pointer |
| G10 | primitives/flex | focus | Flex does not focus or handle input | `flex takes no focus and handles no key or pointer input` (Overview) | Pointer |
| G11 | primitives/flex | scroll | Flex does not scroll | `flex never scrolls` (Overview) | Scroll |
| G12 | primitives/flow | focus | Flow takes no focus and handles no input | `flow takes no focus and handles no key or pointer input` (Identity and focus) | Pointer |
| G13 | primitives/flow | focus | focus order is depth-first source order; Flow places items in source order so focus order and reading order agree | `flow focus order follows source order and agrees with reading order` (Identity and focus) | Focus |
| G14 | primitives/flow | scroll | (evidence only) Flow does not scroll; lines that must stay reachable go in a ScrollView | `flow never scrolls` (Line breaking; Overview) | Scroll |
| G15 | primitives/frame | pointer | frame's final allocated frame clips hit testing of non-text children | `frame clips hit testing of a non-text child to its final allocated frame` (Overview; Sizing: bounded frame) | Pointer |
| G16 | primitives/grid | focus | Grid handles no input | `grid takes no focus and handles no key or pointer input` (Overview) | Pointer |
| G17 | primitives/grid | scroll | Grid never scrolls itself | `grid never scrolls itself` (Overview) | Scroll |
| G18 | primitives/label | focus+pointer | Label has no focus or keys; no pointer behaviour | `label takes no focus, keys or pointer input` (Overview) | Pointer |
| G19 | primitives/label | clock | Label reads no clock | `label reads no clock` (Decisions) | Clock |
| G20 | primitives/leading-rail | focus+pointer | no focus, no key handling; no pointer handling | `leading rail takes no focus and handles no key or pointer input` (Overview) | Pointer |
| G21 | primitives/overlay | pointer | a point inside the primary bounds reaches the overlay layer before the primary (topmost first) | `overlay layer is hit before the primary inside the primary bounds` (Open questions: hit testing respects ZStack order) | Pointer |
| G22 | primitives/overlay | pointer | .allowsHitTesting(false) subtrees are skipped by hit testing | `overlay hit testing skips a layer marked allows hit testing false and reaches the primary` (Open questions: decorative overlay decision) | Pointer |
| G23 | primitives/overlay | pointer | bubbling and click-to-focus follow Slice 5 routing; Overlay installs no input handler | `overlay installs no input handler and supplies only paint order to hit-test routing` (Open questions: hit testing respects ZStack order) | Pointer |
| G24 | primitives/padding | pointer | hit-testing clip region is Padding's final frame, not the child's intrinsic bounds; padding owns no input | `padding hit testing clips to its own final frame and owns no input` (Sizing; placement: final frame) | Pointer |
| G25 | primitives/scroll-indicator | clock | (Overview) no animation | `scroll indicator draws no animation` (Overview) | Clock |
| G26 | primitives/stacks | focus+pointer | stacks take no press or focus behaviour; name no hit regions | `stacks take no press or focus behaviour and name no hit region` (Decisions and deferred scope) | Pointer |
| G27 | primitives/stacks | scroll | stacks never scroll | `stacks never scroll` (Decisions and deferred scope) | Scroll |
| G28 | primitives/style-modifiers | focus+pointer | style modifiers add no focus; the style wrapper has no hit-testing behaviour | `style modifiers add no focus and no hit-testing behaviour` (Overview; Environment) | Pointer |
| G29 | primitives/text | scroll | Text never creates scroll state | `text never creates scroll state` (Degradation) | Scroll |
| G30 | primitives/view-that-fits | focus+pointer | ViewThatFits itself takes no focus and handles no input | `view that fits takes no focus and handles no input of its own` (Identity, state, and focus) | Pointer |
| G31 | primitives/view-that-fits | focus | focused node leaving the order clears focus to nil, recorded in statistics, no neighbour guessed | `a switch that drops the focused id clears focus without guessing a neighbour and records it in statistics` (Identity, state, and focus: focus table, no focusable with id row) | Focus |
| G32 | primitives/view-that-fits | focus | focusable outside the ViewThatFits is untouched by a switch | `a focusable around the whole choice keeps focus across a switch` (Identity, state, and focus: focus table) | Focus |
| G33 | primitives/view-that-fits | focus | same FocusID in two candidates is listed once (chosen only) | `a focus id held by two candidates is listed once for the chosen one` (Identity, state, and focus: focus table; state model: focus membership) | Focus |
| G34 | primitives/view-that-fits | scroll | a candidate ScrollView's offset survives a switch and is clamped on its next layout as chosen | `a chosen-again scroll view candidate clamps its kept offset on its next layout` (state model: candidate state) | Scroll |
| G35 | primitives/z-stack | pointer | hit testing visits children topmost first (later over earlier) | `zstack hit testing visits children topmost first with later children over earlier` (Allocation; Decisions: Slice 5 hit testing) | Pointer |
| G36 | widgets/button | focus | printable characters focused: no state change, bubbles | `focused button leaves printable characters unconsumed and unchanged` (key table: printable characters) | Focus |
| G37 | widgets/button | focus | Esc while isPressed cancels the press without invoking; not consumed | `esc while a press is pending cancels it without invoking and is not consumed` (key table: Esc) | Focus |
| G38 | widgets/button | focus | isPressed cleared on node removal and every update where the node is not focused | `button clears isPressed on node removal and on every update where it is not focused` (state model: is pressed) | Focus |
| G39 | widgets/button | pointer | click-to-focus first, then primary down sets isPressed | `pointer press focuses the button before it sets isPressed` (mouse table: click) | Pointer |
| G40 | widgets/button | pointer | double-click: no distinct gesture; each valid same-node click invokes once | `double-click is no distinct gesture and each valid same-node click invokes once` (mouse table: double-click) | Pointer |
| G41 | widgets/button | pointer | drag while pressed: release outside the node clears isPressed and never invokes; not consumed | `button clears a pending press when a pointer release leaves its node` (mouse table: drag) | Pointer |
| G42 | widgets/button | pointer | hover cleared on motion-tracking disable and node removal; disabled button renders as not hovered | `hover clears when motion tracking stops or the node is removed, and a disabled button renders as not hovered` (state model: is hovered; mouse table: move) | Pointer |
| G43 | widgets/callout | focus+pointer | Callout is not focusable: no key table, no responder, no keys; no mouse table, no pointer behaviour | `callout takes no focus, keys or pointer input` (Key table; Mouse table) | Pointer |
| G44 | widgets/code-view | focus+pointer | CodeView takes no focus and consumes no keys; takes no pointer input in 1.0 | `code view takes no focus, keys or pointer input in 1.0` (Key table; Mouse table) | Pointer |
| G45 | widgets/content-unavailable-view | focus+pointer | the view owns no keys, no responder and no pointer regions | `content unavailable view owns no keys, responder or pointer regions` (Key table; Mouse table; State model (delegation)) | Pointer |
| G46 | widgets/content-unavailable-view | focus+pointer | action Buttons are ordinary focusable Buttons with their own key and mouse tables | `content unavailable view action buttons keep their own focus, key and click behaviour` (Key table; Mouse table; State model (delegation)) | Pointer |
| G47 | widgets/form | focus | Form is one focus stop; Tab moves past it | `form is one focus stop and tab moves past it` (State model; Key table; Overview) | Focus |
| G48 | widgets/form | focus | cursor clamped to field count | `form cursor clamps to the field count when fields disappear` (state model: cursor) | Focus |
| G49 | widgets/form | focus | PgUp/PgDn move the cursor one window, clamped | `page up and page down move the form cursor one window and clamp` (key table: PgUp, PgDn) | Focus |
| G50 | widgets/form | focus | Left/Right on enum row cycles; on number row steps clamped to min/max | `left and right cycle an enum row and step a number row clamped to its range` (key table: Left, Right) | Focus |
| G51 | widgets/form | focus | Left/Right on other row kinds: no effect, not consumed | `left and right on other row kinds are not consumed` (key table: Left, Right) | Focus |
| G52 | widgets/form | focus | Enter/Space on bool row toggles; on enum row cycles forward | `enter or space toggles a bool row and cycles an enum row forward` (key table: Enter, Space) | Focus |
| G53 | widgets/form | focus | Enter/Space on text row starts editing; on number row no effect | `enter or space starts editing on a text row and does nothing on a number row` (key table: Enter, Space) | Focus |
| G54 | widgets/form | focus | editing keys: Backspace, Ctrl-U, Ctrl-W, Space, printable; all other keys no effect | `editing keys insert, delete and clear text on a text row and all other keys do nothing` (key table: editing text) | Focus |
| G55 | widgets/form | focus | Enter/Esc stops editing | `enter or escape stops editing a text row` (key table: editing text) | Focus |
| G56 | widgets/form | focus | paste appends with newlines/tabs replaced by spaces while editing; ignored when not editing | `paste appends to a text row being edited with line breaks and tabs as spaces and is ignored otherwise` (key table: paste) | Focus |
| G57 | widgets/form | pointer | click on row: click-to-focus first, activates the row as Enter does | `clicking a form row focuses the form first and activates the row as enter does` (mouse table: row) | Pointer |
| G58 | widgets/form | pointer | editing/open flags cleared on outside click | `a click outside the open row clears the editing and open flags` (state model: editing and open flags) | Pointer |
| G59 | widgets/form | pointer | hover cleared on focus loss and when motion tracking stops | `form hovered row clears on focus loss and when motion tracking stops` (state model: hovered row; mouse table: move) | Pointer |
| G60 | widgets/form | scroll | scroll offset NodeState clamped to content rows minus window rows on every render | `form scroll offset clamps to the content rows minus the window rows on every render` (state model: scroll offset) | Scroll |
| G61 | widgets/form | scroll | a field taller than the window top-aligns | `form field taller than the window top-aligns when chased` (state model: scroll offset) | Scroll |
| G62 | widgets/form | scroll | wheel at boundary not consumed | `wheel at a form boundary is not consumed` (mouse table: wheel-up, wheel-down) | Scroll |
| G63 | widgets/key-legend | focus | no focused responder declares none -> empty legend; no magic overlay | `legend with no focused responder bindings is empty and adds no overlay` (state model: bindings; API) | Focus |
| G64 | widgets/key-legend | focus | bindings recomputed on every focus change and render; never stored; nothing in NodeState | `legend bindings are recomputed on every focus change and stored nowhere` (state model: bindings) | Focus |
| G65 | widgets/key-legend | focus | declaring a binding installs no behaviour; graph still routes keys without interpreting them | `declaring a key binding installs no behaviour and keys route as before` (state model: bindings) | Focus |
| G66 | widgets/key-legend | pointer | KeyLegend takes no pointer input | `legend takes no pointer input` (Mouse table) | Pointer |
| G67 | widgets/list | focus | List is one focus stop: rows not individually focusable, Tab moves past the whole widget | `list is one focus stop and tab moves past the whole widget` (Anatomy; State model; Key table) | Focus |
| G68 | widgets/list | focus | hosted in a focus-appearance host the host paints its focus rule; selection-less List follows ScrollView's delegated focus appearance | `list leaves its focus treatment to a hosting box and without a selection binding follows the scroll view's delegated focus appearance` (state model: selection style; scroll-view focus appearance) | Focus |
| G69 | widgets/list | focus | Up/Down saturate at first/last selectable row and stay consumed | `up and down at the first and last selectable row saturate and stay consumed` (key table: Up, Down) | Focus |
| G70 | widgets/list | focus | Home/End select first/last selectable row | `home and end select the first and last selectable row` (key table: Home, End) | Focus |
| G71 | widgets/list | focus | PgUp moves selection one viewport of rows up, clamped (list.md:356 covers PgDn only) | `page up moves selection to the item one viewport of rows above` (key table: PgUp) | Focus |
| G72 | widgets/list | pointer | click on data row: click-to-focus runs first; consumed | `click on a data row focuses the list before it selects and is consumed` (mouse table: click) | Pointer |
| G73 | widgets/list | pointer | right and middle clicks have no List use | `right and middle clicks have no list use` (mouse table) | Pointer |
| G74 | widgets/list | pointer | click or drag on scroll indicator is not routed (output-only) | `click or drag on the list scroll indicator is not routed` (mouse table: scroll indicator) | Pointer |
| G75 | widgets/list | scroll | without a selection binding boundary arrows leave offset unchanged and are not consumed | `without a selection binding boundary arrows leave the offset unchanged and are not consumed` (key table: Down, binding absent) | Scroll |
| G76 | widgets/list | scroll | selection may scroll out of view under wheel scrolling; bar/fill not rendered until it returns | `selection scrolled out of view by the wheel draws no bar or fill until it returns` (state model: scroll offset) | Scroll |
| G77 | widgets/multi-picker | focus | menu: Up/Down/Home/End move cursor as Picker's menu (edge clamp, no wrap), selection unchanged | `multipicker menu up, down, home and end move the cursor with edge clamping and leave the selection unchanged` (key table: menu) | Focus |
| G78 | widgets/multi-picker | focus | menu: PgUp/PgDn move cursor by viewport rows | `multipicker menu page up and page down move the cursor by viewport rows` (key table: menu PgUp and PgDn) | Focus |
| G79 | widgets/multi-picker | focus | Enter editing with empty draft ends editing; Esc editing clears draft | `multipicker empty draft Enter ends editing and escape clears the draft` (key table: menu Enter, editing; menu Esc) | Focus |
| G80 | widgets/multi-picker | focus | Esc when not editing bubbles | `multipicker menu escape outside editing bubbles` (key table: menu Esc) | Focus |
| G81 | widgets/multi-picker | focus | Backspace/Ctrl-U/Ctrl-W/printable edit draft; other keys swallowed while editing | `multipicker draft editing keys edit the draft and swallow all other keys` (key table: editing rows) | Focus |
| G82 | widgets/multi-picker | focus | digit on custom row starts editing and moves cursor to it | `multipicker menu digit on the Other row moves the cursor and starts editing` (key table: menu digits) | Focus |
| G83 | widgets/multi-picker | focus | Left/Right/other keys in menu bubble; unfocused, disabled or empty group returns Skip | `multipicker left, right and unlisted keys bubble and an unfocused, disabled or empty group leaves keys unconsumed` (key table: menu; radio) | Focus |
| G84 | widgets/multi-picker | focus | radio group with zero options installs no handler | `multipicker radio group with no options installs no handler` (key table: radio) | Focus |
| G85 | widgets/multi-picker | focus | host row closed: other keys bubble | `multipicker closed host row bubbles keys other than enter and space` (host keys: closed) | Focus |
| G86 | widgets/multi-picker | focus | host row open: Up/Down clamp; Left/Right/other keys consumed; Tab/Shift-Tab bubble | `multipicker open host row clamps up and down, consumes left, right and unlisted keys, and bubbles tab and shift-tab` (host keys: open list) | Focus |
| G87 | widgets/multi-picker | focus | disabled host row is absent from focus and cannot open | `disabled multipicker host row is absent from focus and cannot open` (state model: open; host keys) | Focus |
| G88 | widgets/multi-picker | focus | ? cursor and checked-chip underline drawn only while focused | `multipicker draws its cursor and underlines checked chips only while focused` (state model: is focused) | Focus |
| G89 | widgets/multi-picker | pointer | every click that acts installs the MultiPicker's focus first | `a multipicker click that acts installs the multipicker's focus first` (mouse table; host mouse) | Pointer |
| G90 | widgets/multi-picker | pointer | menu click while editing ends editing, discards the draft, then toggles | `multipicker menu click while editing ends editing and discards the draft before it toggles` (mouse table: menu option row) | Pointer |
| G91 | widgets/multi-picker | pointer | click on title row or below last option bubbles | `multipicker menu click on the title row or below the last option bubbles` (mouse table: menu) | Pointer |
| G92 | widgets/multi-picker | pointer | zero-option menu wheel bubbles | `multipicker menu wheel with zero options bubbles` (mouse table: menu wheel) | Pointer |
| G93 | widgets/multi-picker | pointer | radio group gutter/gap clicks, wheel and other mouse bubble | `multipicker radio group clicks outside chips, wheel and other mouse input bubble` (mouse table: radio) | Pointer |
| G94 | widgets/multi-picker | pointer | click when disabled leaves everything unchanged, not consumed | `disabled multipicker click leaves everything unchanged and unconsumed` (mouse table: disabled) | Pointer |
| G95 | widgets/multi-picker | pointer | host row: click on closed row opens; click on open row closes | `multipicker host row click opens a closed list and closes an open one` (host mouse) | Pointer |
| G96 | widgets/multi-picker | pointer | host row: click on option row moves cursor, toggles, list stays open | `multipicker host row click on an option row moves the cursor and toggles with the list staying open` (host mouse) | Pointer |
| G97 | widgets/multi-picker | pointer | host row: click outside closes without committing and bubbles | `multipicker host row click outside closes the list without committing and bubbles` (host mouse) | Pointer |
| G98 | widgets/multi-picker | pointer | host row: wheel in open list moves cursor clamped, consumed | `multipicker host row wheel in an open list clamps at the edges and is consumed` (host mouse) | Pointer |
| G99 | widgets/multi-picker | scroll | menu scroll offset clamped to 0...max(0, content rows - visible rows) | `multipicker menu scroll offset clamps to zero through the last content row` (state model: scroll offset) | Scroll |
| G100 | widgets/multi-picker | scroll | reveal re-applies to the cursor row | `multipicker menu reveal re-applies to the cursor row by the fewest rows` (state model: scroll offset) | Scroll |
| G101 | widgets/multi-picker | scroll | options taller than the viewport align first row with top | `multipicker option taller than the viewport aligns its first row with the top` (state model: scroll offset) | Scroll |
| G102 | widgets/multi-picker | scroll | title row outside the scrolling region | `multipicker title row stays outside the scrolling region` (state model: scroll offset; Menu) | Scroll |
| G103 | widgets/outline | focus | Outline is focusable via explicit .focusable | `outline joins focus only through an explicit focusable id` (State model; Key table) | Focus |
| G104 | widgets/outline | focus | is-focused drives the selection bar: accent when focused, secondary otherwise | `outline selection bar is accent while focused and secondary otherwise` (State model: is focused; Anatomy) | Focus |
| G105 | widgets/outline | focus | Right on a leaf and Left on a root row bubble | `right on a leaf and left on a root row bubble` (Key table: Right, Left) | Focus |
| G106 | widgets/outline | scroll | scroll offset clamps to content bounds on every update | `outline scroll offset clamps to the content bounds on every update` (State model: scroll offset) | Scroll |
| G107 | widgets/outline | scroll | selection-moving keys reveal the new row | `selection-moving keys reveal the new row by the fewest rows` (State model: scroll offset; Key table) | Scroll |
| G108 | widgets/picker | focus | no option / disabled / unfocused -> arrow keys bubble | `picker with no options or without focus leaves arrow keys unconsumed` (key table: inline) | Focus |
| G109 | widgets/picker | focus | radio/segmented from absent value writes first option | `picker radio group and segmented control write the first option from an absent value` (key table: radio; segmented) | Focus |
| G110 | widgets/picker | focus | single option consumes Left/Right and leaves selection unchanged | `picker radio group and segmented control with one option consume left and right and leave the selection unchanged` (key table: radio; segmented) | Focus |
| G111 | widgets/picker | focus | menu Home/End consumed even when already there | `picker menu home and end are consumed even when the cursor is already there` (key table: menu Home and End) | Focus |
| G112 | widgets/picker | focus | menu Enter/Space commit the cursor option (picker.md:1323 covers Enter only) | `picker menu space commits the cursor option through the binding` (key table: menu Enter and Space) | Focus |
| G113 | widgets/picker | focus | menu editing: empty draft Enter ends editing | `picker menu empty draft Enter ends editing` (key table: editing rows) | Focus |
| G114 | widgets/picker | focus | Esc with custom row chosen (not editing) clears the draft; Esc otherwise bubbles | `picker menu escape outside editing bubbles unless the custom row is chosen` (key table: menu Esc) | Focus |
| G115 | widgets/picker | focus | host row open: PgUp/PgDn/Home/End move the cursor like the menu | `picker open host list page and home and end keys move the cursor like the standalone menu` (key table: host open list) | Focus |
| G116 | widgets/picker | focus | host row open: Up/Down clamp; Left/Right/other keys consumed; Tab/Shift-Tab bubble | `picker open host row clamps up and down, consumes left, right and unlisted keys, and bubbles tab and shift-tab` (key table: host open list) | Focus |
| G117 | widgets/picker | focus | disabled host row absent from focus and cannot open | `disabled picker host row is absent from focus and cannot open` (Menu collapsed in a host row; state model) | Focus |
| G118 | widgets/picker | focus | inline row focus uses the focus role | `picker inline row draws its focus in the focus role` (state model: is focused; focus presentation) | Focus |
| G119 | widgets/picker | focus | cursor index starts on chosen option or first option and is not written to selection | `picker cursor starts on the chosen or first option and never writes the selection` (state model: cursor index) | Focus |
| G120 | widgets/picker | focus | KeyLegend shows `1-9 choose` for menu | `key legend shows 1-9 choose for a picker menu` (key table: menu digits; KeyLegend) | Focus |
| G121 | widgets/picker | pointer | any click that selects installs Picker's focus first in every presentation | `a picker click that selects installs the picker's focus first in every presentation` (mouse table; host mouse) | Pointer |
| G122 | widgets/picker | pointer | chevrons not independently clickable (no focus, no change) | `picker inline chevrons are not independently clickable` (mouse table: inline row) | Pointer |
| G123 | widgets/picker | pointer | radio/segmented: gutter/gaps and i beyond count bubble; radio wheel bubbles | `picker radio group and segmented control clicks outside chips and radio wheel input bubble` (mouse table: radio; segmented) | Pointer |
| G124 | widgets/picker | pointer | menu: click custom row starts/continues editing | `picker menu click on the custom row starts or continues editing` (mouse table: menu custom row) | Pointer |
| G125 | widgets/picker | pointer | menu: click on option row while editing ends editing and discards the draft first | `picker menu click while editing ends editing and discards the draft before it commits` (mouse table: menu option row) | Pointer |
| G126 | widgets/picker | pointer | menu: click title row or below last option bubbles | `picker menu click on the title row or below the last option bubbles` (mouse table: menu) | Pointer |
| G127 | widgets/picker | pointer | zero-option menu wheel bubbles | `picker menu wheel with zero options bubbles` (mouse table: menu wheel) | Pointer |
| G128 | widgets/picker | pointer | host row: click closed opens as Enter; click open closes without committing | `picker host row click opens a closed list and closes an open one without committing` (host mouse) | Pointer |
| G129 | widgets/picker | pointer | host row: click option row moves cursor, commits, closes | `picker host row click on an option row moves the cursor, commits and closes` (host mouse) | Pointer |
| G130 | widgets/picker | pointer | host row: click outside closes without committing and bubbles | `picker host row click outside closes the list without committing and bubbles` (host mouse) | Pointer |
| G131 | widgets/picker | pointer | host row: wheel in open list clamps, consumed; wheel on closed host row bubbles | `picker host row wheel clamps in an open list and bubbles on a closed row` (host mouse) | Pointer |
| G132 | widgets/picker | scroll | menu scroll offset clamped on every reconciliation and after width re-wrap | `picker menu scroll offset clamps to zero through the last content row and after a width re-wrap` (state model: menu scroll offset) | Scroll |
| G133 | widgets/picker | scroll | option taller than viewport aligns first row with top | `picker option taller than the viewport aligns its first row with the top` (state model: menu scroll offset) | Scroll |
| G134 | widgets/picker | scroll | title row outside the scrolling region | `picker title row stays outside the scrolling region` (Menu scrolling in rows) | Scroll |
| G135 | widgets/picker | scroll | open list in a host row scrolls in rows like the standalone menu | `picker open host list scrolls in rows like the standalone menu` (Host row; Menu scrolling in rows) | Scroll |
| G136 | widgets/progress-view | focus+pointer | not focusable, consumes no key input, no responder; no pointer regions | `progress view takes no focus, keys or pointer input` (Key table; Mouse table) | Pointer |
| G137 | widgets/progress-view | clock | ASCII-only output draws line at 120 ms for every set | `ascii-only indeterminate view declares the line set's 120 ms tick requirement` (frame sets; degradation) | Clock |
| G138 | widgets/progress-view | clock | custom set = frames + interval | `custom spinner set declares its own interval as the tick requirement` (frame sets; state model: tick requirement) | Clock |
| G139 | widgets/progress-view | clock | tick requirement recomputed on every update; aggregated by the graph over live nodes | `tick requirement is recomputed on every update and aggregated by the graph over live nodes` (state model: tick requirement) | Clock |
| G140 | widgets/progress-view | clock | no reduced-motion setting in 1.0 | `progress view has no reduced-motion setting in 1.0` (state model; Open questions) | Clock |
| G141 | widgets/scroll-view | focus | explicit external identity registers unconditionally | `an explicit external focus identity registers unconditionally` (state model: owned focus eligibility) | Focus |
| G142 | widgets/scroll-view | focus | non-focus initializer (no binding/no focus) receives no keyboard scroll events | `scroll view without an offset binding or focus identity receives no keyboard scroll events` (Key table) | Focus |
| G143 | widgets/scroll-view | focus | Tab remains unclaimed; unlisted keys bubble | `scroll view leaves tab and unlisted keys unconsumed` (Key table) | Focus |
| G144 | widgets/scroll-view | focus | disabled (isEnabled) gates focus eligibility | `disabled scroll view is not focus eligible` (state model: owned focus eligibility) | Focus |
| G145 | widgets/scroll-view | focus | reveal on focus change: nothing moves without a controlled offset | `focus reveal moves nothing without a controlled offset` (Key table: reveal on focus change) | Scroll |
| G146 | widgets/scroll-view | pointer | click on viewport content: click-to-focus before handler routing; ScrollView returns ignored | `click on viewport content gets click-to-focus and the scroll view returns ignored without reinterpreting it` (Mouse table: click) | Pointer |
| G147 | widgets/scroll-view | pointer | no pointer capture / second gesture recognizer introduced | `scroll view introduces no pointer capture or second gesture recognizer` (Decisions; Mouse table) | Pointer |
| G148 | widgets/scroll-view | pointer | no Shift-wheel or signed deltas | `scroll view ignores shift-wheel and signed wheel deltas` (Mouse table) | Scroll |
| G149 | widgets/scroll-view | pointer | hit testing deepest-first: an inner ScrollView gets a wheel first | `an inner scroll view receives the wheel before an enclosing one` (Mouse table; Decisions) | Scroll |
| G150 | widgets/scroll-view | scroll | controlled out-of-range binding never rewritten passively; next user movement writes from the effective value | `the next user movement writes from the effective value of an out-of-range controlled offset` (state model: controlled offset) | Scroll |
| G151 | widgets/split-view | focus | each live divider focusable with a manager-only FocusID derived from adjacent pair + axis | `each live divider is focusable with a focus id derived from its adjacent pane pair and axis` (Interaction: focus; state model) | Focus |
| G152 | widgets/split-view | focus | divider focusable only while keyboardResizingEnabled and the pair has an adjustable cell | `divider is focusable only while keyboard resizing is enabled and the pair has an adjustable cell` (Interaction: focus; state model) | Focus |
| G153 | widgets/split-view | focus | focused divider handle cleared if pair disappears, becomes non-resizable or axis changes | `focused divider handle clears when its pair disappears, becomes non-resizable or the axis changes` (state model) | Focus |
| G154 | widgets/split-view | focus | removed focused node still clears focus | `removing the focused node still clears focus` (Interaction: collapse restoration) | Focus |
| G155 | widgets/split-view | pointer | click on divider handle: click-to-focus; pane config unchanged; consumed | `clicking a divider handle focuses it and leaves pane configuration unchanged` (mouse table: click) | Pointer |
| G156 | widgets/split-view | pointer | drag only along main axis; cross-axis ignored | `divider drag follows the main axis only and ignores cross-axis movement` (mouse table: drag) | Pointer |
| G157 | widgets/split-view | pointer | pointer drag cancelled on axis change, focus loss, node identity loss, pane removal | `pointer drag cancels on axis change, focus loss, node identity loss and pane removal` (state model: pointer drag) | Pointer |
| G158 | widgets/split-view | pointer | no hover, wheel or click-to-collapse behaviour | `split view has no hover, wheel or click-to-collapse behaviour` (Decisions; mouse table) | Pointer |
| G159 | widgets/split-view | pointer | handles remain fully interactive in ASCII; one-cell handle available without mouse capability | `split view handles stay interactive under ASCII and show a one-cell handle without mouse capability` (Degradation; mouse table) | Pointer |
| G160 | widgets/stepper | focus | Up/Right increment, Down/Left decrement (stepper.md:371-372 trace Up/Down only) | `stepper treats right as increment and left as decrement like up and down` (key table: Right, Left) | Focus |
| G161 | widgets/stepper | pointer | pressed affordance set only on valid primary down or phased key down; cleared on release, cancellation, focus loss, disablement, removal, affordance unavailable | `stepper pressed affordance sets only on a valid primary down or phased key down and clears on release, cancellation, focus loss, disablement, removal or an unavailable affordance` (state model: pressed affordance) | Pointer |
| G162 | widgets/stepper | pointer | click on value slot or separators: no handler, unconsumed | `click on the stepper value slot or separators has no handler and is unconsumed` (mouse table) | Pointer |
| G163 | widgets/tab-view | focus | every other key bubbles; unfocused tab view handles no keys | `tab view bubbles every key except left and right and handles no keys while unfocused` (key table) | Focus |
| G164 | widgets/tab-view | focus | ASCII cursor >, active tab flat bold label in focus while focused else accent | `ascii tab view draws the cursor as > and the active tab as a flat bold label in focus while focused and accent otherwise` (states; Degradation: ASCII) | Focus |
| G165 | widgets/tab-view | focus | binding matching no tab: no pill, empty pane, cursor still shows while focused | `focused tab view with no matching tab shows its cursor with no pill and an empty pane` (state model: selection; states) | Focus |
| G166 | widgets/tab-view | pointer | wheel-up/down and drag on frame: no effect, not consumed | `wheel and drag on the tab frame have no effect and are not consumed` (mouse table) | Pointer |
| G167 | widgets/table | focus | selection.inactive when unfocused | `unfocused table renders its selection in the inactive style` (state model: selection style) | Focus |
| G168 | widgets/table | focus | single-select Down/Up move selection via binding; saturate and stay consumed | `down and up move the selection through the binding and saturate consumed at the ends` (key table: Down, Up) | Focus |
| G169 | widgets/table | focus | Home/End first/last | `home and end select the first and last row` (key table: Home, End) | Focus |
| G170 | widgets/table | focus | PgDn/PgUp one viewport | `page up and page down move selection one viewport of rows and clamp` (key table: PgUp, PgDn) | Focus |
| G171 | widgets/table | focus | Down with unset selection selects first visible row | `down with no selection selects the first visible row` (key table: Down, selection not set) | Focus |
| G172 | widgets/table | focus | cursor moves never write selection | `cursor moves never write the selection` (state model: cursor) | Focus |
| G173 | widgets/table | pointer | single-select click on data row sets selection via binding; consumed | `click on a data row in single-select sets the selection through the binding and is consumed` (mouse table: click) | Pointer |
| G174 | widgets/table | scroll | row taller than viewport aligns first row with top | `table row taller than the viewport aligns its first row with the top` (state model: scroll offset) | Scroll |
| G175 | widgets/table | scroll | scroll offset and cursors have one runtime owner (not mirrored into ResponderState) | `table scroll offset and cursors are not mirrored into responder state` (state model: scroll offset) | Scroll |
| G176 | widgets/text-field | focus | focused frame heavy in focus (NO_COLOR heavy bold, ASCII +-\|) | `focused text field draws its frame heavy in the focus role, bold under NO_COLOR and plus-hyphen-bar under ASCII` (Degradation; Anatomy) | Focus |
| G177 | widgets/text-field | focus | focus lost/node removed clears focus and the cursor request | `focus loss or node removal clears the field's cursor request` (state model: caret terminal position) | Focus |
| G178 | widgets/text-field | focus | zero width yields no cursor request | `a zero-width text field requests no hardware cursor` (state model: caret terminal position) | Focus |
| G179 | widgets/text-field | focus | Left/Right one grapheme; Shift-Left/Right extend selection from anchor | `left and right move the caret one grapheme and shift extends the selection from the anchor` (key table: Left, Right, Shift-Left, Shift-Right) | Focus |
| G180 | widgets/text-field | focus | Alt-Left/Right word boundary; Ctrl-Left/Right word boundary only when protocol distinguishes else bubbles | `alt arrows move by word and control arrows do so only when the keyboard protocol distinguishes them, otherwise they bubble` (key table: Alt-Left, Alt-Right, Ctrl-Left, Ctrl-Right) | Focus |
| G181 | widgets/text-field | focus | Home/End; Home resets reveal to leading boundary; End reveals the end | `home and end move the caret to the leading and trailing boundary and set the reveal offset` (key table: Home, End) | Focus |
| G182 | widgets/text-field | focus | unlisted keys bubble | `unlisted keys bubble from a text field` (key table) | Focus |
| G183 | widgets/text-field | focus | no undo/yank, no clipboard in 1.0 | `text field has no undo, yank or clipboard behaviour in 1.0` (Deferred post-1.0; key table) | Focus |
| G184 | widgets/text-field | pointer | mouse requirement declared only while an enabled TextField is live; input line is the one hit region | `text field declares a mouse requirement only while an enabled instance is live and the input line is its one hit region` (Mouse table) | Pointer |
| G185 | widgets/text-field | pointer | double-click and drag on input line: no change, bubble; right and middle clicks no use | `double-click and drag on the input line bubble unchanged and right and middle clicks have no use` (mouse table) | Pointer |
| G186 | widgets/text-field | scroll | horizontal reveal offset clamps to a legal grapheme boundary on every layout/update (placed Focus, see Disagreements D2) | `text field reveal offset clamps to a legal grapheme boundary on every layout` (state model: horizontal reveal offset) | Focus |
| G187 | widgets/text-field | clock | no animated cursor / software caret | `text field draws no animated cursor and no software caret` (Anatomy; render contract) | Clock |
| G188 | widgets/toggle | focus | release after focus loss/disablement/removal only clears pressed, never inverts | `release after focus loss, disablement or removal clears pressed state without inverting` (key table) | Focus |
| G189 | widgets/toggle | focus | printable characters focused: no state change, bubbles | `focused toggle leaves printable characters unconsumed and unchanged` (key table: printable characters) | Focus |
| G190 | widgets/toggle | focus | isPressed cleared on release, cancellation, focus loss, disablement, removal, every unfocused update | `toggle clears isPressed on release, cancellation, focus loss, disablement, removal and every unfocused update` (state model: is pressed) | Focus |
| G191 | widgets/toggle | pointer | double-click: no distinct gesture, each valid same-node click inverts once | `double-click is no distinct gesture and each valid same-node click inverts once` (mouse table: double-click) | Pointer |
| G192 | widgets/toggle | pointer | no move row: Toggle draws no hover and requests no pointer motion | `toggle draws no hover and requests no pointer motion` (mouse table: no move row) | Pointer |
| G193 | widgets/toggle | pointer | hit target is the whole control (not marker-only); below marker floor no marker and no hit target | `toggle hit target is the whole control and disappears below the marker floor` (mouse table; sizing) | Pointer |
| G194 | widgets/image | clock | (evidence only) Loading shows a static placeholder (no spinner/animation) | `image loading placeholder is static and draws no spinner or animation` (State model: load phase) | Clock |

### 2d. Dropped as covered (behaviour -> covering requirement)

- **primitives/background**: pointer: layer hit-tested by default / decorative layer must opt out with allowsHitTesting(false) -> background.md:147 (name states explicit opt-out is required, i.e. no implicit decorative default)
- **primitives/badge**: focus: no focus, no keys -> badge.md:325
- **primitives/border**: focus: self focus heavy ring -> border.md:253; focus within nearest ring -> border.md:254; tint switch off by focusWithinBorder(false)/focusSection -> box.md:348; cursor rows -> border.md:255, form.md:1235; unfocused stepper keeps arrows -> stepper.md:381; SplitView divider and joints -> border.md:256, split-view.md:660-661; bordered table -> border.md:257, table.md:784; heavy/double/ASCII rings -> border.md:258-259; focus role no hue every tier -> border.md:260
- **primitives/box**: focus: self focus -> box.md:343; focus within -> box.md:344-345; nested -> box.md:346; nothing focusable inside -> box.md:347; switch off -> box.md:348; delegated focus appearance (Box paints after descendants, ScrollView keeps key ownership) -> scroll-view.md:520; ASCII/NO_COLOR/16-colour -> border.md:259-260
- **primitives/divider**: focus: junction draws in focus role where a focused SplitView line meets it -> border.md:256, split-view.md:661 (the "otherwise border role" half is static and belongs in plain Requirements)
- **primitives/flow**: focus: NodeState survives a reflow / focus preserved -> flow.md:313; radio chips focus cursor gutter (a Picker/MultiPicker behaviour, D11) -> picker.md:1316; multi-picker drafted in Gaps
- **primitives/scroll-indicator**: focus: takes no focus -> scroll-indicator.md:377; pointer: installs no click/wheel/key/drag/hit region -> scroll-indicator.md:377; click or drag falls through to parent which returns .ignored -> scroll-view.md:542, form.md:1291, table.md:759, (list gap drafted)
- **primitives/text**: focus: installs no responder, never focusable, key dispatch continues, never creates focus -> text.md:371; pointer: click/drag/wheel not consumed -> text.md:371
- **primitives/view-that-fits**: focus: membership recomputed / unchosen candidates out of focus order / never focused so never key-routed -> view-that-fits.md:313; same id keeps focus -> :314; no focusable with id clears -> :315; pointer: unchosen never hit -> :303; terminal requirements aggregate over every live node -> :316 (placed Focus, see Disagreements D4); scroll: offset above the VTF survives -> :312 (generic node state)
- **widgets/button**: focus: joins focus only when explicit and enabled; disabled absent -> button.md:605, :607; focused look -> :579, :583-586; focused+pressed -> :613; NO_COLOR/ASCII -> :592-593; Enter/Space phased and legacy -> :599-603; release after focus loss/disable only clears -> :604; Enter/Space when disabled -> :605; defaultAction -> :611; cancelAction -> :612; disablement clears isPressed and removes from focusability -> :604-605. pointer: same-node click -> :606; click when disabled -> :605; move/hover target, underline, derived never stored -> :589, :608, :610; hover consumer only through built-in style -> :609; hit target is the final frame, forced width -> :598
- **widgets/content-unavailable-view**: (none of the participation behaviours is covered; both drafted in Gaps)
- **widgets/form**: focus: cursor starts on first row and keeps its row -> form.md:1292; Up/Down not consumed at ends -> :1283; Enter/Space opens Picker menu -> :1284; dropdown keys belong to Picker -> :1285; focus loss closes dropdown -> :1286; editing cleared on focus loss -> :1293; focus presentation and ASCII cursor -> :1235-1237, :1254; failing field -> :1258. pointer: click sets cursor and closes other dropdown -> :1287; click on open dropdown -> :1288; scrollbar ignored -> :1291; wheel -> :1290; hover -> :1239. scroll: chase -> :1280; partly visible field -> :1279 (unmarked add); scrollbar reservation geometry -> :1281 (static)
- **widgets/image**: focus/pointer: takes no focus, keys or pointer input -> image.md:394
- **widgets/key-legend**: focus: takes no focus and consumes no keys -> key-legend.md:277; entries from focused responder bindings -> :276; legendPriority/drop-by-priority/narrow/floor/ASCII/NO_COLOR rows -> :265, :268, :269, :270, :264-267, :271-275 (all unmarked but moved to Focus, see Placement)
- **widgets/labeled-content**: focus/pointer: no node state, no focus, keys and pointer events bubble -> labeled-content.md:379
- **widgets/list**: focus: arrow auto-commit -> list.md:322; Down unset -> :323; skips headers -> :324; collapse/hidden selection -> :329-330; Left/Right -> :331; Enter -> :336; unfocused tint -> :342; bar accent/secondary -> :347; absent binding arrows scroll -> :335; PgDn -> :356 (exception, Focus). pointer: double-click -> :337; click row -> :338; header toggle -> :339 (non-collapsible header -> section.md:192); hover fill, motion request, disabled, hovered row, clears -> :359-364; wheel boundary -> :327. scroll: clamp -> :333; reveal -> :350-352; width re-measure -> :353; wheel -> :326; re-expansion no auto-scroll -> :332; partly visible -> :349 (unmarked add)
- **widgets/markdown**: focus/pointer: takes no focus, keys or pointer input -> markdown.md:506; clock: no streamed reveal -> :515 (the link-click-is-OSC-8 note is static, markdown.md:505)
- **widgets/multi-picker**: focus: Space toggles -> multi-picker.md:553; Enter bubbles/never toggles -> :554-555; digits -> :556-557; Other row Space/click -> :573; accepted draft -> :574; rejected draft keeps editing -> :575; no duplicates -> :577; radio group Space/Enter/Left-Right/Up-Down -> :585-587, :591; host closed Enter/Space -> :597; host open Space/Enter/Esc/digit -> :598-600, :606; focus loss closes -> :601; paste -> :561. pointer: menu click -> :559; wheel moves cursor consumed -> :560; Other row click -> :573; radio click -> :588; no move row -> :562. scroll: wheel moves cursor, reveal scrolls -> :560, :566
- **widgets/navigation-split-view**: (no participation entry; see Disagreements D5) rows :349-352 are existing requirements that cover the key table and mouse table
- **widgets/outline**: focus: tree keys -> outline.md:488, :492-498; pointer: click/expander/double-click -> :499-500; wheel and boundary -> :501-502; scroll: scrolls itself -> :470; indicator/virtualization static -> :471, :485
- **widgets/picker**: focus: absent cycle -> picker.md:1284; inline advance/retreat -> :1285-1286; endpoints bubble -> :1287; disabled unfocusable -> :1290; radio/segmented wrap -> :1313-1314, :1362; menu clamp -> :1322; menu Enter -> :1323; PgUp/PgDn -> :1335 (exception, Focus); custom row editing, rejected draft, Esc, committed row -> :1341-1346; digits -> :1367-1370; host closed/open keys -> :1380-1385; paste -> :1326; focus presentation -> :1316, :1358-1359. pointer: value-slot click -> :1288-1289; radio/segmented click -> :1315, :1363; menu click -> :1327; wheel -> :1325; no hover -> :1296. scroll: menu scrolls/partial items -> :1333; reveal -> :1334
- **widgets/progress-view**: clock: frame derived from clock, stores no state -> progress-view.md:489; tick requirement/determinate none/orbit fallback interval -> :490-492; built-in sets and intervals -> :487; label at c2 for every set -> :481; ASCII line / custom fallback glyph sets -> :484-485 (static, plain)
- **widgets/scroll-view**: focus: whileScrollable registers/withdraws -> scroll-view.md:523; arrows/page/home/end -> :516-517; boundary bubbling -> :518; repeats -> :525; focus-within bubbling -> :526; reveal on focus change -> :543, :512; focus appearance -> :520-522; owned identity needs offset binding -> :524. pointer: wheel -> :539-541; indicator/corner clicks ignored -> :542. scroll: effective offset, clamp, never rewrite -> :514-515, :538 (static/Scroll); reveal/partial/paging -> :510-512; no animation -> :531
- **widgets/section**: focus: header not focusable -> section.md:186; forwards row focus/bindings -> :193; collapse via List Left/Right -> list.md:331; hidden selection -> list.md:329, section.md:194 (static); pointer: header click -> :191; non-collapsible -> :192; grouped rows forwarded -> :193
- **widgets/split-view**: focus: arrows/first press -> split-view.md:634-636; Shift-arrow -> :650; `=` -> :651; Tab/Esc -> :637; look -> :649, :660-662; collapse restoration -> :632-633. pointer: drag -> :638-639; stale drag -> :640; double-click -> :652; grab zone -> :653; vertical transpose -> :648
- **widgets/stepper**: focus: increment/decrement/endpoint/stride/clamp -> stepper.md:371-379; focus mark -> :384; disabled -> :387; arrows visible unfocused/limit disabled -> :381-382. pointer: arrow click focuses first -> :385; endpoint click unconsumed -> :386; disabled click -> :387
- **widgets/tab-view**: focus: wrap Left/Right -> tab-view.md:436-438; cursor/pill focus presentation -> :445-447, :450. pointer: chip click -> :440-441; outside chip -> :442; move input/no hover -> :443-444
- **widgets/table**: focus: Enter -> table.md:767; multi-select keys -> :791-793; header mode -> :797-801; outer ring -> :784-785; bar cell -> :814. pointer: multi click/gutter/double-click -> :788-790; header click -> :764; hover -> :815-820; indicator output-only -> :759. scroll: stays visible/synchronized -> :756-757; wheel -> :758; clamp -> :762; thumb/paging -> :821; partly visible row -> :822 (unmarked add)
- **widgets/text-field**: focus: printable/paste/IME -> text-field.md:444-446; clamps -> :447-448; replace selection -> :449; no caret inside graphemes -> :450; reveal -> :451; Enter/Tab/Esc -> :456-458; Backspace/Delete -> :459; hardware cursor -> :461; disabled -> :462; character limit never caps -> :468 (static). pointer: click -> :460; disabled click -> :462
- **widgets/toggle**: focus: Enter/Space exactly once -> toggle.md:461-462; disabled -> :460; focus feedback -> :469-470, :459; shared contract across styles -> :478. pointer: click-to-focus then same-node inversion -> :463; drag release outside -> :464; forced-width hit target -> :454; text-style row click -> :479

Docs whose participation entry lists only `none` roles with no behaviours (readable-width; the unlisted capabilities of every doc above) need nothing.

## 3. Disagreements

- **D1** widgets/key-legend.md: participation puts `focus: own` and lists layout rows (priority, narrow drops, 20-column floor, ASCII, NO_COLOR, keycaps) as Focus behaviours, but the classifiers left 261-275 and 278 unmarked as static. Evidence/resolution: Participation is right on the testability: `KeyLegend()` takes no arguments and "reads the focused responder chain's bindings from the environment" (key-legend.md API, state model: bindings). A legend with entries cannot exist before declared bindings (slice 04). All 16 unmarked rows added to Focus. Role is arguably `affects` (the view takes no focus) but the placement is the same. Counter-case: if tests inject a bindings environment value directly, these 16 stay plain.
- **D2** widgets/text-field.md: participation `scroll: own` for the horizontal reveal offset (while noting "static fixture is testable today"). Evidence/resolution: The reveal offset is derived from the caret (keys/edits/click); it uses no wheel, bubbling, ScrollIndicator or viewport. It is caret/edit machinery, so Focus. Scroll role should be `none`; its behaviours (clamp, minimal adjust, Home/End) are drafted in Focus (G rows for text-field) and text-field.md:451 is Focus.
- **D3** widgets/picker.md and widgets/multi-picker.md: participation `scroll: own` includes "wheel moves the cursor (no separate offset wheel)". Evidence/resolution: The wheel moves the CURSOR and is always consumed (never bubbles); that is Pointer. Only the menu offset behaviours (clamp, reveal, taller option, title outside region, partial items) are Scroll. picker.md:1325 and multi-picker.md:560 placed Pointer.
- **D4** primitives/view-that-fits.md: participation puts "terminal requirements aggregate over every live node" under `pointer: affects` (mouse tracking as example). Evidence/resolution: view-that-fits.md:272 links it to slice 04 `terminal-requirements-aggregation` (focus and key routing). The aggregation machinery lands with Focus; row :316 added to Focus. The Pointer role of VTF is only "unchosen candidates are never hit" (:303).
- **D5** widgets/navigation-split-view.md has no entry in participation.jsonl although it has 14 requirements. Evidence/resolution: Its rows :349 (focus continuity), :350 (no keys/no pointer handlers), :351 (divider drag), :352 (inactive tint on column focus loss) are capability-bound and were unmarked; added. The doc should get a participation entry with focus `affects`, pointer `affects`.
- **D6** widgets/scroll-view.md (and the List/Table/Outline/Form/Picker "scroll indicator ... (static)" items): participation `scroll: own` lists static behaviours (viewport proposals, indicator visibility/reservation, effective offset with a binding, partial item draws, below-12x4 omission). Evidence/resolution: ScrollView offset is a Binding the test sets, and indicator geometry is "testable today" (scroll-indicator.md evidence). Those rows are plain; only input-driven behaviours (wheel, keys, reveal, bubbling, paging of the offset, unbound origin hold) are Scroll. Unmarked scroll-view rows 503-509, 511, 513-515, 519, 527-529 left plain.
- **D7** widgets/progress-view.md: participation `clock: own` bundles static behaviours (label at c2, glyph sets, ASCII fallback glyph) with time-dependent ones. Evidence/resolution: Only the frame-from-instant, interval, tick-requirement and no-reduced-motion behaviours need Clock. Glyph-set resolution is plain (see D9 assumption).
- **D8** widgets/markdown.md: participation `clock: none` with no behaviours. Evidence/resolution: markdown.md:515 ("does not reveal streamed source in 1.0") is a stated negative about time-driven reveal; the clock role should be `none` WITH that negative behaviour, expected to have a requirement (it does; placed Clock).
- **D9** Assumption flagged, not a participation error: whether a test can supply a clock instant before Clock lands. Evidence/resolution: progress-view.md:413 makes the clock an Environment value "supplied by the app or the Phase 5 runtime". If the value type only exists with Clock, rows progress-view.md:477, 482-486, 488 (plain) and any indeterminate-spinner fixture move to Clock. Rows 481, 487, 489-492 are Clock regardless (they assert across frames or the tick requirement).
- **D10** widgets/section.md: participation `focus: own`. Evidence/resolution: Section consumes no keys; the host List dispatches Left/Right (participation's own first behaviour). Role should be `affects`. No placement change (section.md:186 Focus, :191-192 Pointer, :193 Pointer).
- **D11** primitives/flow.md: participation lists "radio-group chips: focus cursor gutter beside a Flow" as a Flow focus behaviour. Evidence/resolution: That is Picker/MultiPicker behaviour (picker.md:1316; multi-picker gap). Flow's own focus behaviours are the NodeState-survives-reflow row (flow.md:313) and the drafted source-order focus rule. Flow `scroll` evidence ("does not scroll") has no listed behaviour; an evidence-only negative is drafted.
- **D12** primitives/overlay.md: participation lists "bubbling and click-to-focus follow Slice 5 routing" as an Overlay pointer behaviour. Evidence/resolution: That is generic hit-test routing, not Overlay behaviour; the Overlay-specific content is paint order and "installs no input handler". Drafted as one combined requirement.
- **D13** widgets/image.md: participation `clock: none` evidence says the Loading placeholder is static (no spinner/animation) but lists no behaviour. Evidence/resolution: Stated negative; an evidence-only draft is included (image Clock row in 2c). Same for primitives/flow.md scroll.
- **D14** Placement disagreement with the classifiers (not the participation audit): paging rows list.md:356, outline.md:495, picker.md:1335. Evidence/resolution: Classified focus+scroll, giving Scroll by the rule. They assert only the target of a selection/cursor move by V static viewport rows; the offset is neither input nor observable in the assertion, and the offset effect is covered by separate reveal rows. Marked EXCEPTION -> Focus. If Main prefers "paging is always Scroll", flip these 3 and the 5 PgUp/PgDn drafts (list, table, form, multi-picker menu, picker open host list) from Focus to Scroll.

## 4. Summary

| subsection | marked rows | unmarked adds | total placed | drafted gap requirements |
|---|---|---|---|---|
| Focus | 192 | 27 | 219 | 87 |
| Pointer | 81 | 2 | 83 | 72 |
| Scroll | 37 | 4 | 41 | 27 |
| Clock | 8 | 0 | 8 | 8 |
| none | 1 | 0 | 1 | 0 |
| **total** | 319 | 33 | 352 | 194 |

- Marked rows resolved to a single subsection: 319 of 319 (28 borderlines resolved; progress-view.md:477 resolved to `none`).
- EXCEPTION rows: 3 (list.md:356, outline.md:495, picker.md:1335, all Focus instead of Scroll).
- Multi-capability marked rows: 60; latest-landing rule applied to all except the 3 exceptions and the borderline resolutions noted in their rows.
- Unmarked rows added to Placement: 33 (16 key-legend, 4 form open-dropdown, 1 picker and 2 multi-picker open-list/uncheck, 1 table cursor, 4 navigation-split-view (2 Focus, 2 Pointer), 1 view-that-fits, 4 Scroll).
- Drafted gap requirements: 194 (text-selection: 9 behaviours listed, 0 drafted). Two are evidence-only (flow scroll, image clock).
