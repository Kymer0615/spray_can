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

Return clicks left — press it again within your Mac's double-click speed to double-click (General → Press Return twice to double-click; any other key ends the window and goes to the app); `[` clicks middle; `]` clicks right; `\` double-clicks left. Modifiers pass through to click events. **⇧Return is Shift-click, not double-click**. Space or `=` holds left; the labels stay, so typing another label drags there, and Space, `=`, or Return releases it. A held drag glides to each destination in small steps, because some apps (including the macOS screenshot tool, ⇧⌘4) ignore a drag that jumps. Escape after clearing any prefix, ⌘H, mode reactivation, and session interruptions release a held button.

With **Let macOS shortcuts work during navigation** on (the default, in General), ⌘ and ⌃ shortcuts that Spray Can has no binding for — ⌘C, ⌘V, ⌘W, ⌘Space, ⌃Space, and so on — go to macOS and the app while labels are shown. Spray Can's own bindings below still win, and plain, Shift, and ⌥ keys never pass through. Turn the setting off to have Spray Can capture every key during navigation.

Esc / ⌘. / ⌃G clear a partial label or queued input; with no prefix they exit. Delete removes a prefix character. ⌘, opens Settings. ⌃= toggles grid lines; ⌃⇧= toggles labels; ⇧⌘= / ⇧⌘− change cell size; ⌘= / ⌘− change background opacity when glass and Reduce Transparency are both off.

When the target window or app changes, Elements and Scroll modes re-scan and show fresh labels; any partial label is cleared. ⌘Tab and ⌘` pass through to macOS, and labels follow the newly focused window once Command is released. Repeated label keys are ignored, while repeated movement and scroll keys are accepted. Input is queued during discovery (up to 32 events). Queue overflow gives visible feedback; Escape clears it.

## Dedicated scroll mode

| Action | Key |
| --- | --- |
| Left / down / up / right | H J K L |
| Half-page left / down / up / right | ⇧H ⇧J ⇧K ⇧L |
| Half-page down / up | D / U (unshifted) |
| Top / bottom | GG (two unshifted G presses) / ⇧G |
| Next / previous scroll area | Tab / ⇧Tab |
| Exit | Esc / ⌃[ |

Top/bottom use large pixel scroll events; virtualized/infinite lists may require repeated commands. Scrolling glides smoothly, and holding a key scrolls continuously; set **Scroll smoothness** in General (Off scrolls instantly). macOS sends scroll events wherever the pointer is, so by default scroll mode doesn't move the pointer and scrolls whatever is under it; Tab moves the pointer into the next scroll area. Under **Pointer in scroll mode** you can instead have it wait inside the active area — at its right, left, or bottom edge, its bottom-right corner, or its center. A moved pointer returns to where it was when scroll mode ends. J always scrolls down and K up, whether or not natural scrolling is on; the same holds for the scroll shortcuts in the other modes.

Apps that expose no accessibility scroll areas, such as VS Code and other Electron apps, scroll whatever is under the pointer: point at the editor, terminal, or sidebar first (with element labels or the grid), then activate scroll mode. If the pointer is outside the window, Tab moves it to the app's content area.
