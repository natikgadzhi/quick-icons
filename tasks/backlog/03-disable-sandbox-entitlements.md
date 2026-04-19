---
dependencies: []
status: backlog
---

# Disable Sandbox and Configure Entitlements

## Objective

QuickIcons needs to spawn `swiftc` as a subprocess and `dlopen` user-compiled dylibs at runtime. Both are blocked by the macOS app sandbox. Since QuickIcons is a developer tool (not an App Store candidate), disable the sandbox and add the entitlements needed for dynamic library loading.

## Acceptance Criteria

- [ ] `ENABLE_APP_SANDBOX = NO` in both Debug and Release target build settings
- [ ] `com.apple.security.cs.disable-library-validation` entitlement is present
- [ ] App still builds and passes the unit test suite after the change
- [ ] `xcodebuild build` produces no new warnings related to entitlements

## Changes Required

In `QuickIcons.xcodeproj/project.pbxproj`, for both the Debug and Release `QuickIcons` target build configurations:

```
ENABLE_APP_SANDBOX = NO;
```

Remove the `ENABLE_USER_SELECTED_FILES` setting (it's only meaningful with sandbox enabled).

Add a `QuickIcons.entitlements` file at `QuickIcons/QuickIcons.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
```

Set `CODE_SIGN_ENTITLEMENTS = QuickIcons/QuickIcons.entitlements` in the target build settings.

## Notes

- The NSOpenPanel for export still works without sandbox — it just no longer needs a special entitlement
- `disable-library-validation` is required for `dlopen` to load ad-hoc-signed or unsigned dylibs that the user compiles at runtime
- This entitlement is allowed for notarized apps distributed outside the App Store
- `ENABLE_HARDENED_RUNTIME = YES` must stay on (required for notarization)
