# Nova

SketchUp extension for cabinet design and production prep.

Install: copy `Plugins/nova.rb` and `Plugins/nova/` into your SketchUp `Plugins` folder and restart.

## Features
- **Cabinet library + parameter panel** – base / wall / tall / corner / decorative presets; one panel drives
  size, thickness, toe kick, back type, shelves, doors, drawers, reveals, hinges and handles.
  Applying new values rebuilds the selected cabinet and slides the rest of the run (quick stretch).
- **Handles & hinges** – rule-based handle placement (centre / offset, vertical / horizontal); changing the
  rule and applying updates the cabinet. Hinge cup markers are generated per door.
- **Pre-flight check** – error / warning list (invalid dimensions, impossible drilling, edge-banding, grain,
  oversize doors, panel collisions); click a row to select the cabinet, or mark problem panels in the model.
- **Labels & QR** – label sheet per panel (A1, A2 ...) with a QR payload (needs internet for the QR library).
- **Grain matching, door open/close, QuickToolBar, nesting layout** – see the toolbar.

`Plugins/nova/cabinet.rb` and `checker.rb` are plain Ruby (no SketchUp calls in the panel/check logic).

Not implemented yet: room-space recognition, mortise/slot machining, per-panel fine tuning,
non-rectangular corner units, nesting export (DXF / CNC).
