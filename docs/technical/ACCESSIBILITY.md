# Accessibility readiness

## Implemented baseline

- SwiftUI text uses semantic text styles so Dynamic Type can scale; template metadata falls back to a vertical layout and the guided-shot card scrolls at accessibility sizes.
- Reduce Motion disables repeating icon effects, entrance offsets, card bounces, and spring navigation. Reduce Transparency removes decorative film grain.
- Shot progress indicators are 44-point buttons with explicit shot, completion, and current-state VoiceOver values.
- Camera icon controls expose action-oriented labels for close, torch, microphone, camera switching, recording, and zoom.
- Template, film, recovery, audio-mix, export, and recording controls expose meaningful labels, values, and hints without relying on color alone.
- Title editing includes a keyboard Done action. Core actions remain reachable without drag gestures through Previous/Next and reorder buttons.
- Stable accessibility identifiers support launch and accessibility-text-size UI smoke tests.
- User-facing SwiftUI literals use localization-aware controls; template content remains versioned JSON so future localized catalogs can preserve stable ids.

## Release audit still required

Run on the oldest supported iPhone and representative current devices:

1. Complete every create/import/camera/edit/preview/export path with VoiceOver enabled.
2. Repeat at Accessibility XXXL and verify no action, error, permission recovery, or destructive confirmation is clipped.
3. Verify Increase Contrast, Differentiate Without Color, Reduce Motion, Reduce Transparency, Bold Text, Button Shapes, and Voice Control.
4. Test hardware-keyboard focus, dismissal, tab order, and Full Keyboard Access across sheets and navigation.
5. Pseudolocalize and test right-to-left layout before adding a second locale; do not translate template ids or shot ids.
6. Record issues by screen, content-size category, assistive setting, device, and OS version. P0/P1 accessibility defects block TestFlight promotion.

## Verification

```bash
make verify
make ios-test
```

`make ios-test` requires a healthy CoreSimulator service. Physical-device assistive-technology testing remains mandatory because compile and simulator smoke tests cannot validate spoken order, camera ergonomics, microphone routing, contrast in real capture conditions, or motor-access behavior.
