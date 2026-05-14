
# "Runbook" App

## Intro

This doc enumarates the goals of this project, as stated by the user. As an agent, you should accomplish these goals and update this doc accordingly.

## Overview

We are building an app tentatively called "Runbook", which is a sophisticated tracker app for dog sports enthusiasts. The target audience here is extremely small and generally are not tech-saavy, but they love keeping track of their dogs' stats and progress towards titles. Many people keep track of everything on pen-and-paper, relying on their own knowledge of each title's requirements to figure out what they've achieved. At higher levels of each sport, this gets extremely complicated.

## The App

We will build an app in Dart+Flutter that compiles to Android, iOS, and web. The app has two main functions:

 - Show a "card UI" feed of read-only reports, achievements, etc.
 - Show a searchable and editable history of "Qs" (qualifying runs) in various sports.

There is no server -- the app is local only with only on-device storage (for now), even for the web version.

### Required Functionality

 - CRUD for dog profiles -- users should be able to add a dog with basic info such as call name, breed, height at whithers, etc. Everything except call name must be optional.
 - CRUD for Qs -- users should be able to quickly add a Q, specifying a sport, a date, a score, etc, depending on the sport.
 - Scroll through a feed of "cards" -- UI elements that represent reports, titles, notes of encouragement, etc.
 - Pin and unpin cards to the feed.

### Conversational Design Language

The app should *not* involve navigation menus, context menus, wizards, forms, or other traditional app mechanics. Instead, the UX should be *conversational*, similar to Lemonade Insurance. We will not be using AI to drive these conversations, but rather simple decision trees which are hard-coded. For example, when adding a dog, the UI should present the user with a choice of dogs or an option to add a new one. Choosing to create a new dog does not open a new "activity" -- instead, the conversation then proceeds to ask what the dogs name is, etc. At any time, the user may go back and change options selected in the convo so far, which may cause the decision tree to go in a different direction. This just involves scrolling up -- not hitting the back button!

We do not necessarily want this to feel like chatting with a dynamic AI. Users will likely add many Qs manually, so the goal is to make the process as quick and easy as possible. For example, adding many Qs for the same dog should be possible without starting the whole convo over again. Nor should anything be artificially delayed (we are not simulating an LLM or human). We want a conversational style without the slowness usually associated with that.

### The Feed

The core of the app is the feed, which is a single place to find reports, titles, messages, etc. This is similar in nature to an exercise tracker for humans. The feed should be a mix of time-ordered historical events and informative reports/messages. At the top of the feed should be a set of "pinned" cards, as selected by the user. The user can pin/unpin any card. Pinned cards are smaller and rendered with a "flow" laout instead of vertically. Below these all cards are vertical.

### Cards

The primary value of the app (why people will use it) is to monitor progress towards titles. This is similar in concept to acheivements in video games. Each acheivement has a set of requirements, and once met, the acheivement is unlocked. We will generalize the concept of titles to "achievements" generally. An achievement can be completed or in-progress. Any in-progress or completed achievement should appear in the feed. We don't need to worry about showing achievments with zero progress.

Each acheivement should be rendered as a "card" element. These should have 3 ways to render: in the feed, pinned at the top of the feed, or expanded (a full "activity" with back button etc).

### Implementation Notes

The achievement system should involve a hard-coded decision tree, with nodes that gate entire sub-trees. We will hard-code all of AKC's titling requirements into this decision tree. For example, we don't need to worry about evaluating MACH progress unless there is at least one Master-level Q.

Each achievement has a computed timestamp, which captures the time at which the acheivement was unlocked. These are anchored to the Qs that unlocked them. For example, the Agility Excellent title is unlocked on the third Q in Excellent Standard class, so the Agility Excellent acheivement should compute the timestamp as the time associated with the third such Q. 

The feed is constructed dynamically by evaluating the decision tree. We only store Qs -- not titles/acheivements. The order of cards in the feed is governed by their computed timestamps (the time they were unlocked).

Generally, the number of Qs is small (hundreds to thousands), as is the number of titles. Still, we want to evaluate these quickly, so the tree should be carefully structured to gate unnecessary evaluations.

When I say "hard-coded", I do not mean a giant if-then tree -- I mean we will have a data structure filled with acheivements and gating nodes. Some acheivements might be distinct classes with distinct unit tests. Many acheivements will share the same basic shape and thus the same (base)class.

This is essentially a rules engine, but I do *not* want an external rules DSL.

Note that the database of Qs is not expected to be exhaustive. A single Q may trigger many titles to appear in the feed. For example, if all I add is a Masters Jumpers Q, I should see that I've earned a Novice Jumpers title as well, since the MJ Q implies that all required titles have already been acheived. This part is tricky and points to careful structuring of the rules *or* a clever data structure.

Unit tests should be extensive, testing things like "when a dog earns a Excellent Jumpers Q, the Novice and Open Jumpers titles should also fire" etc.

## Status (2026-05-13 MVP)

Iteration 1 — first end-to-end pass:
- Dog/Q models, SharedPreferences-backed repo, AKC agility rules engine (gated tree), conversational UI framework, feed with pinned + scrolling cards.

Iteration 2 — UX + content expansion:
- Add-dog: explicit "Save / Start over" confirmation step (wife was logging dogs 3x because completion wasn't obvious); upsert by call-name (case-insensitive).
- Data model: `Q.preferred` (bool), AgilityClass `premierStandard`/`premierJww`, `Q.yards` / YPS.
- Rules engine: refactored into `TitleProgression` chains (Standard / JWW / Preferred Std / Preferred JWW / Premier Std / Premier JWW / MACH 1-3 / PAX 1-3). LevelQCountTitle handles preferred; PremierCountTitle for PAD/PJD; ChampionTitle parameterized for MACH/MACH2/.../PAX/PAX2/...
- Add-Q convo: asks Regular/Preferred, skips Preferred+level for Premier classes (always Master), edit-existing-Q mode.
- Dog profile page: info, Q list, edit/delete dog, edit/delete each Q.
- Feed: timeline interleaves Q ribbon rows (clustering adjacent Qs into a wrap of pill-ribbons) with achievement cards. Achievement card dog-name is tappable → dog profile.
- Tip cards: "Don't forget your X ribbon!" after each direct unlock; "One more Q until X!" at have == need-1.
- Achievement detail page: full-page with progress bar, chain pills (e.g., NAJ → OAJ → AXJ → MXJ → MJB → ...), contributing Qs (each tap → edit), derived stats (avg time, avg YPS, live MACH/PACH points + double Qs for champion titles).
- Pinned card revamp: in-progress = compact progress card with bar + count; unlocked = strong gold gradient with trophy + dog name.
- Tests: 14 (8 original + Preferred chain + Premier + Master tiers).

Still deferred:
- More sports (only AKC agility today).
- Stacking ribbons (alternative to flow layout).
- Mark-as-collected for "pickup your ribbon" tips.
- Richer Q metadata collection in the convo (yards / time / score) — model supports it, convo doesn't ask for it yet.

## Iteration 3 — Web + functional gap closure (2026-05-14)

- **Web compile path**: `flutter run -d chrome` / `-d web-server` boots Runbook locally; live reload makes iteration ~free vs ~95s APK builds. Manifest + title customized.
- **FAST + T2B chains** added (Regular + Preferred). FAST has NF/OF/XF/MXF; T2B has T2B → T2BCH (Master only). Gated so they only evaluate when matching Qs exist.
- **Preferred badge**: cards now carry a small "PREF" pill so Preferred-division titles read at a glance.
- **Q metadata in convo**: optional steps for course time (s), yards, FAST score, MACH/PACH points. Powers downstream analytics.
- **Trial-day grouping**: feed Q-ribbon clusters now render inside a `TrialDayCard` with a date header, dog name + Q count, and a `DOUBLE-Q` badge when Master Std+JWW were both Q'd on the same day.
- **Mark-as-collected ribbon tips**: pickup reminders carry a "Got it!" button; tapping persists a per-dog/per-achievement flag so the tip stops re-firing.
- **Analytics cards**: data-conditional `AnalyticsFeedItem`s emitted only when enough data exists — fastest run, top YPS, top-3 average, last-N-runs trend with fl_chart sparkline.
- **Q history page**: app-bar search icon → `QHistoryPage` with dog / class / level / division / date-range filters across all dogs.
- **Multi-sport infra**: `Sport` enum (akcAgility / fastCAT / scentwork) on Q, with JSON migration that defaults legacy rows to akcAgility. Rule trees still agility-only; FastCAT and Scentwork title chains are a TODO for whichever sport gets prioritized next.
- **Tests**: 18 (15 prior + FAST/T2B chain coverage + FAST Preferred parallelism).

