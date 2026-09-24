# Shortcut reference

The default profile follows Scoot's source behavior. Global bindings can be recorded in Settings. Labels use physical US letter positions; this keeps input deterministic with non-Latin IMEs. Caps Lock does not alter labels.

## Global

| Mode | Shortcut |
| --- | --- |
| Elements | ⇧⌘J |
| Grid | ⇧⌘K |
| Freestyle | ⇧⌘L |
| Scroll area | ⌃J |

## Movement and scrolling

| Action | System | Emacs | Optional vi |
| --- | --- | --- | --- |
| Up / down / left / right, small step | ↑ ↓ ← → | ⌃P ⌃N ⌃B ⌃F | K J H L (unshifted) |
| Up / down / left / right, full step | ⌥ arrows | ⌥A ⌥E ⌥B ⌥F | ⌃K ⌃J ⌃H ⌃L |
| Top / bottom / left / right screen edge | ⌘ arrows | ⌥< ⌥> ⌃A ⌃E | ⇧K ⇧J ⇧H ⇧L |
| Center, then cycle corners | ⌃L | ⌃L | ⇧M |
| Scroll up / down / left / right | ⇧ arrows | ⇧P ⇧N ⇧B ⇧F | ⌃B ⌃F ⌃I ⌃A |

Small movement is one sixth of the configured grid-cell size. Full movement is one configured cell. Movement clamps at the current display edge when the requested destination is outside every display. To cross a display gap, choose a grid label on the other display.

Global bindings take precedence over local bindings. In vi mode, the default ⌃J scroll activation overlaps the full-step-down binding; rebind global Scroll in Settings if you need that local command.

## Pointer actions

Return clicks left; `[` clicks middle; `]` clicks right; `\` double-clicks left. Modifiers pass through to click events. **⇧Return is Shift-click, not double-click**. `=` holds left, and Return releases it. Escape after clearing any prefix, ⌘H, mode reactivation, and session interruptions release a held button.

Esc / ⌘. / ⌃G clear a partial label or queued input; with no prefix they exit. Delete removes a prefix character. ⌘, opens Settings. ⌃= toggles grid lines; ⌃⇧= toggles labels; ⇧⌘= / ⇧⌘− change cell size; ⌘= / ⌘− change background opacity when glass and Reduce Transparency are both off.

Repeated label keys are ignored, while repeated movement and scroll keys are accepted. Input is queued during discovery (up to 32 events). Queue overflow gives visible feedback; Escape clears it.

## Dedicated scroll mode

| Action | Key |
| --- | --- |
| Left / down / up / right | H J K L |
| Half-page left / down / up / right | ⇧H ⇧J ⇧K ⇧L |
| Half-page down / up | D / U (unshifted) |
| Top / bottom | GG (two unshifted G presses) / ⇧G |
| Next / previous scroll area | Tab / ⇧Tab |
| Exit | Esc / ⌃[ |

Top/bottom use large pixel scroll events; virtualized/infinite lists may require repeated commands. Only scroll areas exposed through accessibility are listed.
