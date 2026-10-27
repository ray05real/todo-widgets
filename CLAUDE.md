# To-do widgets — project brief

A personal iPhone to-do app for the owner only (not for the App Store). Sideloaded, never published.

## Who you are working with
- The owner has **no coding experience**: explain each step in plain English, tell them exactly what to tap.
- Windows PC, **iPhone 16 Pro on iOS 26** (Face ID, Dynamic Island).
- They sideload with a paid certificate through the **Kravasigner** app (ESign is a fallback). No jailbreak.

## What the app must do
- A daily to-do list (usually one a day, reset and refilled around the same time each day; more lists possible).
- Tick items **without opening the app**: Home Screen widget, Lock Screen widget, and a **Lock Screen card that
  looks like an Apple notification** (a Live Activity) that stays up, plus the Dynamic Island.
- Apple ends a Live Activity after 8 hours: the app renews it (a new card replaces the old one) when you tick or
  tap Renew. Ticks on a locked phone only work once Face ID has unlocked it (Apple's rule).

## How it is built (no Mac)
- Swift / SwiftUI, WidgetKit, ActivityKit, App Intents. iOS 26+ (the owner's iPhone is on 26.5; raised from 17 for the toolbar's sharedBackgroundVisibility).
- `project.yml` (XcodeGen) makes the Xcode project on GitHub's Mac; `.github/workflows/build.yml` builds an
  **unsigned** .ipa on every push to main and publishes it as a GitHub Release. The owner downloads it on the
  iPhone and signs it in Kravasigner.
- Tick boxes are `LiveActivityIntent`s, so iOS runs them inside the app process (no app opening), which updates the
  list, the card and the widgets together. The widget extension compiles them with `WIDGET_EXTENSION` set and
  never runs them.
- The widgets can only read the list if the certificate lets app and widgets share storage: `TodoStore` uses an
  App Group if the signature has one, else a shared keychain group (`<team>.todo.shared`, allowed by wildcard
  profiles), else app-only storage. `Signing` reads the real entitlements from the signed binary and the embedded
  profile (the in-app "Test report" was removed once the widget worked; see git history if it is needed again).

## The owner's choices (26 Oct 2026)
- Ticked to-dos **stay where they are** (moving them to the bottom felt overwhelming). Widgets and the card show a
  block of to-dos that fits; the next block appears once the whole block is ticked (`TodoList.window`).
- Rows were too small to hit: bigger text (default 17) and taller rows that grow with the text.
- Font, font size and colour, like Word: a default in Settings, and per to-do (Edit).
- Any number of lists. Each has a start and a length (until the daily reset time, 4 h, 12 h, 24 h, 3 days, a picked
  end, or no end) and a countdown ("resets in 2 hrs, 13 min"; the hourglass alone confused the owner) in the corner.
  The card and widgets title a daily list "TO DO:" (a named one "SHOPPING:"). Lists can be planned ahead; a planned list takes over
  when the current one ends. Widgets follow the current list or a named one (Edit Widget).
- Unfinished to-dos are **not** carried over automatically: they're offered at the top of the next list (+ / ×).
- A notification when a list ends; an optional daily "plan your next list" reminder.

## The Lock Screen card (owner's notes, 26 Oct 2026)
- Apple's Live Activity glass turns light or dark with the wallpaper behind it (dark over a dark wallpaper, cream
  over a light one), while notifications stay dark, so it could never match. The card always sets its own tint
  (`CardTint`: see-through black, 0.32 at the slider's middle mark ≈ notifications, clear at the right end), or
  White (paper-white, dark text) or Black (white text); each look keeps its own brightness (CardSettings shade / whiteShade / blackShade). Glass / Clear glass (`glassEffect`) and See-through were tried and dropped.
- The logo sits top left on the first screen, level with the settings button on the right, in a bar straight under the status bar (16 pt in, like the lists). Not as a list row: the section corners clipped it.
- Lock Screen cards: "Top list only" (one card following the top list; attributes.listID nil) or "Every list" (a
  card per running list with showOnCard on; attributes.listID = the list). LiveCard.sync adds, updates, renews and
  removes cards to match. Widgets: "To-do" (top list), "To-do · 2nd list", "To-do · 3rd list" (by rank in the
  owner's order). The pull-down-from-the-top view is the Lock Screen too: cards can't be hidden there alone.
- The Home Screen widgets are plain StaticConfigurations (kind "TodoListWidget", …2, …3): the
  AppIntentConfiguration ("choose a list") version stayed a grey skeleton on the sideloaded app, even in the Add
  Widget preview (fixed in 0.12, confirmed by the owner).
- Apple caps the card at 160 points tall: it can't be made bigger. 2 columns or smaller text (down to 9) fit more.
- "TO DO" sits top left in an outlined rounded box (no colon); the countdown ("2 hrs, 13 min", no "resets in")
  bottom right. The ↻ renew button was removed (it confused the owner; the card renews itself).
- Switches: card on/off, the count in the Dynamic Island on/off (empty compact views), countdown.
- "Not finished last time" sits below the Add box.
- Swipe left (WhatsApp-style): on a list, Rename / Delete; on a to-do, Edit / Delete; a full swipe deletes. The list's ••• menu only holds the per-list card switch.
- Tips (section footers) are off by default (Settings → Show tips); the owner found them wordy.
- The countdown uses SystemFormatStyle.DateOffset (no seconds), size 13. Where it sits is a setting (CardSettings.timerPlace): top right in the title line (default, costs no to-do), or bottom left / bottom right on its own line under the first / last column. "+N more" (not "1–11 of 12", which read like a ticked count) shows how many come after the ones on show.
- App icon and in-app logo: "To Do" in a box with rounded (continuous) corners and no slit (the owner removed it), one slit each in the T and D like Revolut's R, white-on-black (inverted from black-on-white, owner 26 Oct), shaded with a darker rim (drawn
  with System.Drawing in PowerShell; see git history for the drawing code).

## Status
- 26 Oct 2026: test build worked on the iPhone (widgets, card, Dynamic Island ticks). Second build adds the choices
  above.

## App Store plan (owner, 27 Oct 2026)
- Name "ToDo" (likely taken on the App Store: the store name must be unique, e.g. "ToDo: Lock Screen List"; the name
  under the icon can stay "ToDo"). Price: free download, 7-day free trial, then a £4.99 one-time lifetime unlock.
  Apple's way for one-time purchases (guideline 3.1.1): a £0 non-consumable IAP named like "7-day Trial" plus a £4.99
  non-consumable "Lifetime", with StoreKit 2. Needs the Paid Apps Agreement, bank and tax details in App Store Connect;
  apply for the Small Business Program (15% commission).
- Steps: owner enrols in the Apple Developer Program (£79/yr, also covers Pollz); then proper App Group, privacy
  manifest (UserDefaults reason), ITSAppUsesNonExemptEncryption = NO, signed GitHub build uploading to TestFlight with an
  App Store Connect API key in GitHub Secrets; store listing (privacy policy page, screenshots); review.
- Review risk: Live Activities are meant for things with a clear start and end; "no end" lists and the hourly renewal
  could be questioned.

## Later changes (27 Oct 2026)
- Saved lists (TodoData.saved): a list's ••• → Save for reuse keeps its to-dos under a name (same name replaces);
  Saved on the first screen (tap = new list from it, swipe = Rename / Delete); New list → Start from.
- The build runs on GitHub's `xcode-27` runner (preview) so iOS 27's tall extra-large iPhone widget
  (`.systemExtraLargePortrait`, behind `#if IOS27_SDK`) is offered; the owner's iPhone is on iOS 27.2 now.
- Widget taps after the first sometimes didn't register on iOS 27: iOS ignores taps while the last one's intent runs,
  so a tick only saves and returns: a widget tap leaves the reload to iOS (no reloadAllTimelines, which made a double
  reload), and the card update runs in a Task afterwards (renewing waits until a card is 6 hours old; opening the app
  renews after 1). Then widget taps moved to WidgetToggleIntent, a plain AppIntent that iOS runs in the widget
  extension (no app to wake; it also tries CardContent.updateCards); card and Dynamic Island taps stay
  ToggleItemIntent (LiveActivityIntent, in the app). The widget timeline is just now + the next change.
