# Theme Project Plan

## Goal

Make the custom `Hackerer-Dark` visual stack a first-class theme family in this repo while preserving the existing JaKooLit dark/light theming workflow.

The project has two major workstreams:

1. Fix theme divergence and integrate the custom theme with the existing theming logic.
2. Port the GTK theme language to Qt via Kvantum and aligned Qt color schemes.

## Workstream 1: Theme Convergence and Integration

### Objectives

- Stop update and theme scripts from unexpectedly stomping local visual state.
- Represent the custom theme as a repo-native theme family rather than as local drift.
- Keep the current dark/light switching flow, but route it through theme-family configuration instead of hardcoded assumptions.
- Make dark mode default to the custom `Hackerer` family.

### Deliverables

- A theme family profile format for repo-managed themes.
- A `Hackerer` family profile wired into the theme-switching flow.
- Refactored `DarkLight.sh` logic that separates mode switching from theme-family resolution.
- Deterministic Qt platform theme handling.
- Update-safe preservation of visual state across `copy.sh`.
- Audit checks for theme drift and unsafe visual defaults.

### Tasks

1. Inventory the active visual stack.
   - GTK theme
   - icon theme
   - cursor theme
   - Kvantum theme
   - qt5ct / qt6ct settings
   - Waybar style
   - wallust behavior
2. Define a theme family schema.
   - family name
   - dark assets
   - light assets
   - missing-asset policy per component
   - Qt palette files
   - Kvantum theme name
   - GTK theme names
   - icon theme names
   - cursor theme names
   - optional wallust behavior flags
3. Add a `Hackerer` family profile.
   - `dark` maps to the current custom stack
   - `light` is either deferred, unsupported, or mapped to a temporary fallback until a matching light variant exists
4. Refactor `DarkLight.sh`.
   - separate `mode` from `theme family`
   - stop hardcoding Catppuccin / Flat-Remix assumptions
   - only mutate Qt / GTK / Kvantum through the selected family profile
5. Normalize environment handling.
   - make `QT_QPA_PLATFORMTHEME` deterministic
   - ensure Qt5 / Qt6 behavior is predictable
6. Preserve local theme state during update.
   - snapshot and restore theme files in `copy.sh`
   - avoid first-boot theme resets when local theme files already exist
7. Expand audit coverage.
   - detect duplicate env definitions
   - detect force-applied visual defaults
   - detect likely monospace-UI drift and other visual regressions
8. Document the theme system.
   - how a family is defined
   - how dark/light resolution works
   - how to add a new family

### Risks

- `DarkLight.sh` currently mutates a large number of visual components at once.
- Some theme changes are still encoded as direct script edits instead of declarative theme data.
- A true `Hackerer` family will need explicit rules for what happens when only a dark variant exists.

## Workstream 2: GTK to Qt Port

### Objectives

- Make Qt visually match `Hackerer-Dark` rather than approximating it with loose dark-mode colors.
- Use Kvantum as the primary Qt styling layer, with `qt5ct` / `qt6ct` as support layers.

### Findings So Far

- `Hackerer-Dark` is not just a small CSS override.
- The GTK3 theme imports a generated Numix / Oomox resource bundle.
- The theme ships a large asset set for widget visuals, including checkboxes, radios, and pane handles.
- The GTK2 theme confirms the core design language:
  - black surfaces
  - neon-green foreground and accents
  - square corners
  - flat borders
  - large controls
  - high contrast

### Deliverables

- A new `Kvantum/Hackerer-Dark` theme.
- Matching `qt5ct` and `qt6ct` color schemes.
- A test matrix against actual Qt applications.
- Integration of the Qt port into the `Hackerer` theme family profile.

### Tasks

1. Extract the GTK design language.
   - palette
   - border treatment
   - corner radius
   - spacing and padding
   - hover / active / disabled states
   - asset-backed widgets
2. Choose a Kvantum base theme.
   - prefer a square, flat, minimal dark base that can be bent toward the Hackerer look
3. Port the core Qt visuals.
   - buttons
   - inputs
   - menus
   - tabs
   - checkboxes and radios
   - scrollbars
   - selection colors
4. Recreate or adapt widget assets where needed.
   - checkbox and radio indicators
   - handle / separator visuals if needed
5. Align supporting Qt config.
   - qt5ct colors
   - qt6ct colors
   - icon theme defaults
   - font expectations
6. Test against actual Qt apps.
   - qt5ct
   - qt6ct
   - CopyQ
   - Dolphin
   - additional Qt apps as needed
7. Wire the port into the `Hackerer` family profile.

### Risks

- A high-fidelity match will require Kvantum work, not just palette files.
- GTK-specific behavior and resource styling may not map perfectly to Qt.
- Some compromise may be needed between fidelity and maintainability.

## Recommended Order

1. Finish Workstream 1 first so theme behavior becomes deterministic.
2. Then build the Kvantum / Qt port in Workstream 2.
3. Integrate the new Qt port into the `Hackerer` family.
4. Test update flow and theme switching end to end.

## Success Criteria

- Running `copy.sh` no longer breaks the active visual stack.
- Dark mode defaults to the custom `Hackerer` family.
- Theme switching still works with the JaKooLit workflow.
- Qt apps visually align with the `Hackerer-Dark` GTK theme.
- The custom theme is defined in repo configuration, not only in local machine state.
