import Cocoa
import STTextView
import STPluginNeon
import STTextKitPlus
import TreeSitterResource

/// A thin vendored replacement for `NeonPlugin` that loads BOTH `highlights.scm`
/// and `locals.scm` into its token provider.
///
/// Upstream Plugin-Neon's `Coordinator` only loads `highlightQueryURL`, which
/// means scope-aware captures emitted by `locals.scm` (for example, the
/// function-definition name binding that Xcode colors differently from a
/// project-level method call) never reach the theme. This plugin mirrors the
/// upstream plugin's wiring and extends the token provider to run the locals
/// query alongside `highlights.scm`, merging both capture streams before
/// handing them to Neon's `Highlighter`.
///
/// The plugin is a drop-in replacement for `NeonPlugin` — same `init`
/// surface, same events, same `Theme` type. We keep the vendored surface
/// minimal so the day upstream ships the same fix we can delete this file
/// and flip the import back.
struct LocalNeonPlugin: STPlugin {
    private let theme: Theme
    private let language: TreeSitterLanguage

    init(theme: Theme = .default, language: TreeSitterLanguage) {
        self.theme = theme
        self.language = language
    }

    func setUp(context: any Context) {
        context.events.onWillChangeText { affectedRange, _ in
            let range = NSRange(affectedRange, in: context.textView.textContentManager)
            context.coordinator.willChangeContent(in: range)
        }

        context.events.onDidChangeText { affectedRange, replacementString in
            guard let replacementString else { return }
            let range = NSRange(affectedRange, in: context.textView.textContentManager)
            context.coordinator.didChangeContent(
                context.textView.textContentManager,
                in: range,
                delta: replacementString.utf16.count - range.length,
                limit: context.textView.textContentManager.length
            )
        }

        context.events.onDidLayoutViewport { viewportRange in
            context.coordinator.updateViewportRange(viewportRange)
        }
    }

    func makeCoordinator(context: CoordinatorContext) -> LocalNeonCoordinator {
        LocalNeonCoordinator(textView: context.textView, theme: theme, language: language)
    }
}
