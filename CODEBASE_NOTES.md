# Wingpanel Codebase Notes

## What This Is

Wingpanel is the top panel for elementary OS (Pantheon desktop). It shows the app launcher on the left, a clock/datetime in the center-right area, and system indicators (network, battery, sound, etc.) on the right. It is written in Vala and uses GTK3.

---

## Architecture Overview

```
PanelWindow (Gtk.Window)
└── Gtk.Revealer
    └── Widgets.Panel (Gtk.EventBox, CSS name: "panel")
        └── Gtk.Box (horizontal)
            ├── left_menubar  (IndicatorBar) — app launcher
            ├── center_menubar (IndicatorBar) — center items
            └── right_menubar (IndicatorBar) — clock, system indicators
```

**`PanelWindow`** ([src/PanelWindow.vala](src/PanelWindow.vala))
- Creates and owns the top-level window.
- Talks to the Wayland compositor via the `io_elementary_pantheon_shell_v1` protocol (`desktop_panel`) to anchor the panel to the top and reserve space so apps don't overlap it.
- On X11 falls back to setting `_MUTTER_HINTS` directly.
- Calls `BackgroundManager.initialize(panel_height)` on realize — this `panel_height` value is passed over DBus to Gala so Gala knows how tall the panel exclusion zone should be.
- `update_panel_dimensions()` reads `panel.get_allocated_height()` and calls `set_size_request`. This is the single source of truth for the panel's height.
- `set_expanded()` is called when a popover opens — it expands the window to full screen height so indicator popovers can render.

**`Widgets.Panel`** ([src/Widgets/Panel.vala](src/Widgets/Panel.vala))
- The actual panel widget. CSS name `panel` (set via `set_css_name`).
- `height_request` drives the panel's physical height.
- Listens to `BackgroundManager.background_state_changed` and adds/removes CSS classes (`maximized`, `translucent`, `color-light`, `color-dark`) on itself to change the visual appearance.
- Handles scroll-to-switch-workspaces and window dragging from the panel area.

**`Services.BackgroundManager`** ([src/Services/BackgroundManager.vala](src/Services/BackgroundManager.vala))
- Connects to `org.pantheon.gala.WingpanelInterface` over DBus.
- Gala sends `state_changed` signals with a `BackgroundState` enum value and animation duration whenever the content behind the panel changes (e.g. a window maximizes).
- BackgroundManager forwards these as `background_state_changed` signals to Panel.
- States: `LIGHT`, `DARK`, `MAXIMIZED`, `TRANSLUCENT_DARK`, `TRANSLUCENT_LIGHT`.

**`Services.DisplayConfig`** ([src/Services/DisplayConfig.vala](src/Services/DisplayConfig.vala))
- Queries `org.gnome.Mutter.DisplayConfig` over DBus.
- `is_logical_layout()` — whether Mutter is in logical (scaled) or physical pixel layout mode; used to correct monitor geometry in `PanelWindow.update_panel_dimensions()`.
- `is_edp1_primary()` — returns `true` when the primary display connector is `eDP-1`. This is how the code detects the built-in display (MacBook with notch). Used to set a taller panel height for the notch.

**`Services.PopoverManager`** ([src/Services/PopoverManager.vala](src/Services/PopoverManager.vala))
- Manages which indicator popover is currently open.
- Tells `PanelWindow` to expand/collapse when a popover opens/closes.

**`Widgets.IndicatorBar`** ([src/Widgets/IndicatorBar.vala](src/Widgets/IndicatorBar.vala))
- A horizontal box holding `IndicatorEntry` widgets.
- `insert_sorted()` places indicators in priority order.

**`Widgets.IndicatorEntry`** ([src/Widgets/IndicatorEntry.vala](src/Widgets/IndicatorEntry.vala))
- Wraps a loaded indicator plugin.
- Has a `Gtk.Revealer` so indicators can slide in/out.

---

## CSS / Visual Styling

[data/styles/Application.css](data/styles/Application.css)

The visual background of the bar is drawn **on `panel > box`** (the inner Gtk.Box), not on `panel` itself — except in `MAXIMIZED` state where `panel.maximized { background-color: #000; }` paints the full panel element.

Key rules:

| Selector | Effect |
|---|---|
| `panel` | Always `background-color: transparent` |
| `panel.maximized` | Solid black, full panel height |
| `panel.translucent > box` | Floating pill: `border-radius: 5px 5px 0 0; margin-bottom: 4px` |
| `panel.translucent.color-dark > box` | Semi-transparent dark background |
| `panel.translucent.color-light > box` | Semi-transparent white background |
| `panel.notched.translucent > box` | **Overrides floating pill**: `border-radius: 0; margin-bottom: 0` |

The `notched` class is added in `Panel.vala` when `is_edp1_primary()` is true.

---

## Notch Handling (Current Branch: `notched`)

The device has a hardware notch on the built-in display (`eDP-1`). Two problems had to be solved:

**1. Height — apps must not enter the notch area**

`Panel.height_request` is set to `32` on `eDP-1` (vs `24` on other displays). This makes `panel.get_allocated_height()` return 32, which flows through to:
- `PanelWindow.update_panel_dimensions()` → `set_size_request(monitor_width, ...)` — the GTK window is 32px tall
- `BackgroundManager.initialize(panel_height)` → `bus.initialize(32)` — Gala reserves 32px at the top, preventing apps from overlapping the notch

**2. Visual — the background bar must fill the full notch height**

In translucent states, `panel.translucent > box` has `margin-bottom: 4px`. This is an intentional floating-pill effect on non-notch displays (the bar appears to float slightly above the desktop). On the notch display this caused the visual bar to paint only 28px while the layout reserved 32px — a 4px transparent gap between the bar and where apps begin.

Fix: the `notched` CSS class on `panel` overrides `margin-bottom` to `0` and `border-radius` to `0`, making the background fill the full 32px.

---

## Indicator Loading

Indicators are external shared libraries loaded at runtime from `/usr/lib/wingpanel/`. `IndicatorManager` discovers and loads them. Each exposes a `Wingpanel.Indicator` object with a `code_name`, display widget, and popover widget.

Special `code_name` values:
- `Indicator.APP_LAUNCHER` — goes in `left_menubar`
- `Indicator.DATETIME` — goes in `right_menubar` (sorted by priority)
- Everything else — `right_menubar` (sorted)

---

## Build

```
meson setup build
cd build
ninja
sudo ninja install
```

Requires: `gala >= 8.3.0` for the Pantheon shell Wayland protocol.
