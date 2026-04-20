---
dependencies: [04-wire-sttextview]
status: backlog
---

# Hide Editor Scroll Bars

## Objective

Hide both horizontal and vertical scroll bars in the text editor. The editor
should scroll via trackpad / scroll wheel but not render visible scroller
chrome. Matches Xcode's default appearance.

## Acceptance Criteria

- [ ] No vertical scroller visible in the editor.
- [ ] No horizontal scroller visible in the editor.
- [ ] Trackpad / scroll wheel scrolling still works.
- [ ] The gutter and text still lay out correctly at all window widths.
- [ ] Zero-warning build; tests pass.

## Notes

- In `QuickIcons/Views/STTextViewRepresentable.swift`, the `scrollView`
  returned by `STTextView.scrollableTextView()` is an `NSScrollView`. Set:
  ```swift
  scrollView.hasVerticalScroller = false
  scrollView.hasHorizontalScroller = false
  scrollView.autohidesScrollers = true
  scrollView.scrollerStyle = .overlay
  ```
  The first two remove the scrollers entirely; `autohidesScrollers` +
  `.overlay` is belt-and-suspenders. The first two alone should be enough.
- If horizontal scrolling shouldn't happen at all (long lines wrap), that's a
  separate wrapping decision — out of scope for this task.
- Size: XS.

## Out of Scope

- Line wrapping behavior.
- Custom scrollers / minimap.
