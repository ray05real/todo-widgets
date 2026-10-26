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
- Swift / SwiftUI, WidgetKit, ActivityKit, App Intents. iOS 17+.
- `project.yml` (XcodeGen) makes the Xcode project on GitHub's Mac; `.github/workflows/build.yml` builds an
  **unsigned** .ipa on every push to main and publishes it as a GitHub Release. The owner downloads it on the
  iPhone and signs it in Kravasigner.
- Tick boxes are `LiveActivityIntent`s, so iOS runs them inside the app process (no app opening), which updates the
  list, the card and the widgets together. The widget extension compiles them with `WIDGET_EXTENSION` set and
  never runs them.
- The widgets can only read the list if the certificate lets app and widgets share storage: `TodoStore` uses an
  App Group if the signature has one, else a shared keychain group (`<team>.todo.shared`, allowed by wildcard
  profiles), else app-only storage. `Signing` reads the real entitlements from the signed binary and the embedded
  profile; the app's "Test report" shows them (the owner copies it back).

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
  over a light one), while notifications stay dark, so it could never match. The card now always sets its own tint
  (`CardTint`: see-through black, 0.32 at the slider's middle mark ≈ notifications, clear at the right end), or
  White (paper-white, dark text). Glass / Clear glass (`glassEffect`) and See-through were tried and dropped.
- The Home Screen widget is a plain StaticConfiguration (kind "TodoListWidget") showing the top list: the
  AppIntentConfiguration ("choose a list") version stayed a grey skeleton on the sideloaded app, even in the Add
  Widget preview. Test widgets A and B (TestWidgets.swift) are still in for checking; remove once it works.
- Apple caps the card at 160 points tall: it can't be made bigger. 2 columns or smaller text (down to 9) fit more.
- "TO DO" sits top left in an outlined rounded box (no colon); the countdown ("2 hrs, 13 min", no "resets in")
  bottom right. The ↻ renew button was removed (it confused the owner; the card renews itself).
- Switches: card on/off, the count in the Dynamic Island on/off (empty compact views), countdown.
- "Not finished last time" sits below the Add box.
- App icon: "To Do" in a box, one slit per shape (box, T, D) like Revolut's R, white-on-black (inverted from black-on-white, owner 26 Oct), shaded with a darker rim (drawn
  with System.Drawing in PowerShell; see git history for the drawing code).

## Status
- 26 Oct 2026: test build worked on the iPhone (widgets, card, Dynamic Island ticks). Second build adds the choices
  above.
