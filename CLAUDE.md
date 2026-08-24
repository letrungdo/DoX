# do_x — working rules

Flutter app. Run every Flutter/Dart command through `fvm` (`fvm flutter analyze`,
`fvm flutter test`, `fvm dart format`) — the system SDK does not match the pinned
version.

## Language

- **Code comments, doc comments and identifiers: English.** No Vietnamese in the
  source. User-facing strings are the exception: they live in `lib/l10n/*.arb`
  and are translated there, never hard-coded in a widget.
- Chat with the user in whatever language they wrote in.

## Finishing a change

After the work is done and `fvm flutter analyze` is clean:

1. Run `fvm flutter test`.
2. Format the files you touched with plain `fvm dart format <file>`. The page
   width is declared once in `analysis_options.yaml` (`formatter: page_width`),
   which both the CLI and the VS Code Dart extension read — never pass
   `--line-length`, and never reformat files you did not otherwise change.
3. **Suggest a commit message in English** — Conventional Commits style
   (`feat:`, `fix:`, `refactor:`, `chore:`), imperative, **subject line only**,
   no body. One line that says what changed, e.g.
   `fix: report password and sharing failures inside their dialog`. Suggest it;
   do not commit unless asked.

## Building a new page

Reach for the shared pieces first. A new page that hand-rolls its own scaffold,
dialog or sheet will drift out of line with the rest of the app the moment
anything changes.

### Scaffold — always `AppScaffold`

`lib/widgets/app_scaffold.dart`. The app rotates freely, so in landscape the
display cutout moves to the *side*, where neither `Scaffold` nor `AppBar` insets
anything. `AppScaffold` applies that inset for you.

```dart
AppScaffold(
  appBar: DoAppBar(title: l10n.something),
  body: ...,
)
```

- `top: true` — only for a page with no `appBar`.
- `bottom: true` — only when the content is pinned to the bottom edge; leave it
  off so a scrollable body can run under the home indicator.
- `bodyHorizontal: false` — only for a host whose body is itself a full page
  (a tab shell); the inner page applies its own insets.
- A bare `Scaffold` is correct for exactly one thing: a surface that must bleed
  to every edge, such as the full-screen video player.

### Content width — `contentConstrainedBox()`

`lib/extensions/widget_extensions.dart`, capped at `Dimens.contentMaxWidth`.
Every page uses it so no screen is narrower or wider than its neighbour.

**The page padding goes *inside* the cap, never around it.** Padding outside the
cap makes that page's cards narrower than everyone else's:

```dart
// Correct — card width is contentMaxWidth - 2 * pagePadding, same everywhere.
body: SingleChildScrollView(
  child: Padding(
    padding: Dimens.screenPadding,
    child: content,
  ).contentConstrainedBox(),
),

// Wrong — the cap sits inside the padding and the page comes out pinched.
body: SingleChildScrollView(
  padding: Dimens.screenPadding,
  child: content.contentConstrainedBox(),
),
```

In a sliver, where you must do the maths by hand, mirror it:

```dart
final overflow = constraints.crossAxisExtent - Dimens.contentMaxWidth;
final horizontalPadding =
    Dimens.pagePadding + (overflow > 0 ? overflow / 2 : 0);
```

### Dialogs and bottom sheets — `lib/widgets/dialog/app_modal.dart`

Never call `showDialog` or `showModalBottomSheet` directly. Every modal in the
app goes through one of these, which is what keeps margins, radii, width caps
and safe-area handling identical:

| Need | Use |
| --- | --- |
| Any dialog | `showAppModal<T>(context, builder: ...)` |
| Dialog surface | `AppDialog(title:, message:/content:, actions: [DialogActionButton(...)])` |
| "Are you sure?" | `showAppConfirmDialog(context, title:, message:, isDestructive:)` |
| Form dialog with the cute icon header | `CuteDialog` |
| Any bottom sheet | `showAppBottomSheet<T>(context, title:, builder: ...)` |
| Sheet that picks one value from a list | `showAppOptionSheet<T>(context, title:, options:, selected:)` |

Dialog buttons are always `DialogActionButton` (`primary` / `cancel` /
`destructive` / `destructiveOutline`) — not `TextButton` or `FilledButton`.
`AppDialog` and `CuteDialog` lay them out; do not wrap them in `DialogActions`
yourself.

`showAppBottomSheet` draws the drag handle, the title and the surface itself —
the builder returns only the body.

### Numbers — `lib/constants/dimens.dart`

No new magic numbers for layout. Widths, radii, insets and page padding live in
`Dimens`; if a value is missing, add it there rather than inline.

### Screens and view models

- A screen extends `StatefulScreen` + `ScreenState<S, V>` (`lib/screen/core/`),
  which wires the view model, `initData()` and `onResume()`.
- Routes are declared in `lib/router/app_router.dart`; run
  `fvm dart run build_runner build -d` after adding one.
- A screen behind an auth guard is reached by redirect, so it can be the only
  thing on the stack — give it a back affordance
  (`appBar: Navigator.of(context).canPop() ? const DoAppBar() : null`) or the
  user has no way out.

### A page that backs a bottom tab — `TabReselect`

`lib/screen/core/tab_reselect.mixin.dart`. Mix it in and supply the two
page-specific pieces; the shared re-tap rule comes with it.

```dart
class _NewsScreenState extends ScreenState<NewsScreen, V> with TabReselect {
  @override
  String get tabRouteName => NewsRoute.name;

  @override
  ScrollController get tabScrollController => _scrollController;

  @override
  Future<void> onTabRefresh() => vm.onRefresh();
}
```

The rule, applied identically to every tab: re-tapping a **scrolled** page
rides it back to the top and stops there; re-tapping a page **already at the
top** calls `onTabRefresh()`. Switching *into* a tab always refreshes, wherever
it was scrolled to. Do not scroll or refresh by hand inside `onTabRefresh` —
that is the mixin's job.

Leave `tabScrollController` off only for a page with nothing to scroll, and
leave `onTabRefresh` off only for one with nothing to refetch.

## Orientation

The app does **not** call `SystemChrome.setPreferredOrientations`. Allowed
orientations are declared per platform (iOS `Info.plist`, Android manifest);
setting a preference during launch leaves iOS ignoring the first rotation. Do
not reintroduce that call — lay the page out for landscape instead.

## gstack (REQUIRED — global install)

**Before doing ANY work, verify gstack is installed:**

```bash
test -d ~/.claude/skills/gstack/bin && echo "GSTACK_OK" || echo "GSTACK_MISSING"
```

If GSTACK_MISSING: STOP. Do not proceed. Tell the user:

> gstack is required for all AI-assisted work in this repo.
> Install it:
> ```bash
> git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
> cd ~/.claude/skills/gstack && ./setup --team
> ```
> Then restart your AI coding tool.

Do not skip skills, ignore gstack errors, or work around missing gstack.

Using gstack skills: After install, skills like /qa, /ship, /review, /investigate,
and /browse are available. Use /browse for all web browsing.
Use ~/.claude/skills/gstack/... for gstack file paths (the global path).

## Localization & Validation Rules

- **Strict l10n**: All user-facing strings MUST use `l10n` from `context.l10n`. Never hard-code Vietnamese or English text in widgets.
- **In-place Validation**: Prefer showing errors directly on input fields via `errorText` rather than using `showToast`.
- **Form Dialogs**: Always use `CuteDialog` for data entry forms to ensure consistent layout, scrolling, and keyboard handling.
- **Money Input**: Use `CuteMoneyField` for all currency amounts to get automatic formatting and suggestions.

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Save progress → invoke /context-save
- Resume context → invoke /context-restore
- Author a backlog-ready spec/issue → invoke /spec
