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
  end, or no end) and a countdown (hourglass) in the corner. Lists can be planned ahead; a planned list takes over
  when the current one ends. Widgets follow the current list or a named one (Edit Widget).
- Unfinished to-dos are **not** carried over automatically: they're offered at the top of the next list (+ / ×).
- A notification when a list ends; an optional daily "plan your next list" reminder.

## Status
- 26 Oct 2026: test build worked on the iPhone (widgets, card, Dynamic Island ticks). Second build adds the choices
  above.
