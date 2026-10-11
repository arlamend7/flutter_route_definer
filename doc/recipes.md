# Runnable application recipes

Run `cd example && flutter run -t lib/recipes.dart -d chrome` (or use your own native runner). `example/test/recipes_test.dart` exercises these flows.

## Return to the intended page after login

Open **Protected account**. The guard captures the complete destination, including repeated query values and fragments, in the login URL's `returnTo` query parameter. Signing in replaces the login page with that destination. Signing out triggers `refreshListenable` and removes access to the account content.

`safeReturnLocation` accepts only a local `/account` URI in this example. Extend that explicit allowlist for your application. Reject external schemes/authorities and malformed values; destination guards still run after login. The example's boolean is a demonstration, not an authentication service.

## Independent tabs with retained stacks

Open **Retained tabs**, enter a detail screen and type a draft. Switch tabs, open another detail, then switch back. `IndexedStack` retains both routers and their widgets; each child has its own back dispatcher. Selection gives the active child priority; system back first attempts that child's stack. The parent forgets the dispatchers and disposes the child routers when the tab page is removed.

These are independent local stacks. The parent URL remains `/tabs`; the example does not promise deep links to individual tab screens or automatic restoration of both branches. Map parent URLs to branch selection explicitly if needed.

## Unsaved forms

Open **Unsaved form**, type, and press Back. `PopScope` prevents the pop and opens a confirmation. **Keep editing** retains the draft; **Discard** permits a subsequent pop. **Go home safely** uses the same confirmation before explicitly resetting the stack.

Browser Back/Forward, an incoming external link, and direct `router.go`/`replace` calls replace configuration rather than invoking `PopScope`. This recipe does not intercept them. Keep valuable drafts in application-owned storage if they must survive these actions or process termination. On iOS, a vetoed Cupertino swipe may not invoke the pop callback; provide an explicit back/close action for confirmation.
