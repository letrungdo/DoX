import 'dart:convert';

import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Drives a web page with the television remote.
///
/// A web view is a window onto somebody else's page, and on a television it is
/// a dead one: the page's own controls are not Flutter focus nodes, so the
/// D-pad walks straight past them, and the platform view never takes the
/// Android focus that would let the page handle the keys itself. The sign-in
/// form was reachable only by a touchscreen the device does not have.
///
/// So the page is driven from this side instead. This wraps the web view in a
/// focus node of its own; while the remote is on it the arrows step through the
/// page's own focusable elements — highlighted in the page, scrolled into view
/// there — and OK either presses the element or, for a field, opens the app's
/// own dialog to type into and writes the answer back.
///
/// A pass-through on every other device.
class TvWebNavigator extends StatefulWidget {
  const TvWebNavigator({
    super.key,
    required this.controller,
    required this.child,
    this.autofocus = false,
  });

  /// The web view being driven, or null until it has been created. Read on
  /// every key, so a view that arrives late needs no rebuild here.
  final InAppWebViewController? Function() controller;

  final Widget child;

  final bool autofocus;

  @override
  State<TvWebNavigator> createState() => TvWebNavigatorState();
}

class TvWebNavigatorState extends State<TvWebNavigator> {
  final FocusNode _node = FocusNode(debugLabel: 'tv-web-view');

  /// True while a key is being answered, so holding an arrow down cannot pile
  /// up calls into a page that has not finished moving yet.
  bool _busy = false;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  /// Puts the page's cursor on its first element. Called by the page that owns
  /// the web view once a document has finished loading, because the element
  /// the previous document was on no longer exists.
  Future<void> onPageLoaded() async {
    if (!deviceType.isTv) return;
    await _run('__doxTv.reset()');
    if (_node.hasFocus) await _run('__doxTv.move(1)');
  }

  @override
  Widget build(BuildContext context) {
    if (!deviceType.isTv) return widget.child;
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) {
        if (!hasFocus) _run('__doxTv.clear()');
      },
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.arrowRight:
        _step(1, TraversalDirection.down);
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.arrowLeft:
        _step(-1, TraversalDirection.up);
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.gameButtonA:
        _activate();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// Moves the page's cursor by [delta], and hands the remote back to the app
  /// when the page has run out of elements in that direction — otherwise the
  /// web view would keep the focus for the rest of the session.
  Future<void> _step(int delta, TraversalDirection escape) async {
    if (_busy) return;
    _busy = true;
    try {
      final moved = await _call('__doxTv.move($delta)');
      if (!mounted || moved?['ok'] == true) return;
      _node.focusInDirection(escape);
    } finally {
      _busy = false;
    }
  }

  Future<void> _activate() async {
    if (_busy) return;
    _busy = true;
    try {
      final result = await _call('__doxTv.activate()');
      if (!mounted || result == null) return;
      if (result['type'] != 'text') return;
      final text = await _askFor(
        label: result['label'] as String? ?? '',
        value: result['value'] as String? ?? '',
        obscure: result['secret'] == true,
      );
      if (text == null || !mounted) return;
      await _run('__doxTv.setValue(${jsonEncode(text)})');
    } finally {
      _busy = false;
    }
  }

  /// The app's own dialog, because a television types into a full-screen
  /// keyboard and the page's field is behind it either way.
  Future<String?> _askFor({
    required String label,
    required String value,
    required bool obscure,
  }) {
    return showAppModal<String>(
      context,
      builder: (_) =>
          _TvWebFieldDialog(label: label, value: value, obscure: obscure),
    );
  }

  Future<void> _run(String expression) async {
    await _call(expression);
  }

  /// Runs [expression] against the page, after making sure the page carries
  /// the driver it names. Injected on every call rather than once per load: a
  /// page that navigates on its own — which a sign-in flow does at every step
  /// — would otherwise be left without it.
  Future<Map<String, dynamic>?> _call(String expression) async {
    final webView = widget.controller();
    if (webView == null) return null;
    try {
      final raw = await webView.evaluateJavascript(
        source: '$_driverScript;JSON.stringify($expression)',
      );
      if (raw is! String || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on Object {
      // A page that is between documents, or one that refuses script from
      // outside, simply does not move. Never a reason to take the app down.
      return null;
    }
  }
}

/// Asks for one field's text.
///
/// A widget of its own so the controller lives and dies with the dialog.
/// Popping a route only *starts* it leaving: it is built again for every
/// frame of the exit animation, so a controller disposed the moment the
/// future completed was disposed out from under the field still on screen.
class _TvWebFieldDialog extends StatefulWidget {
  const _TvWebFieldDialog({
    required this.label,
    required this.value,
    required this.obscure,
  });

  final String label;
  final String value;
  final bool obscure;

  @override
  State<_TvWebFieldDialog> createState() => _TvWebFieldDialogState();
}

class _TvWebFieldDialogState extends State<_TvWebFieldDialog> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop<String>(_controller.text);

  @override
  Widget build(BuildContext context) {
    return CuteDialog(
      title: widget.label.isEmpty ? context.l10n.tvWebFieldTitle : widget.label,
      confirmText: context.l10n.ok,
      onConfirm: _submit,
      children: [
        DoTextField(
          controller: _controller,
          obscureText: widget.obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
      ],
    );
  }
}

/// The page-side driver: the cursor over the page's own focusable elements.
///
/// Re-declared on every call, so it survives the page navigating; the cursor
/// itself is kept on `window` and only initialised once.
const _driverScript = r'''
(function () {
  var s = window.__doxTv;
  if (!s) {
    s = window.__doxTv = { el: null };
    var style = document.createElement('style');
    style.textContent =
        '.do-x-tv-focus { outline: 3px solid #4da3ff !important;'
        + ' outline-offset: 2px !important; }';
    document.documentElement.appendChild(style);
  }
  s.items = function () {
    var all = document.querySelectorAll(
        'a[href], button, input, select, textarea, [role="button"],'
        + ' [tabindex]:not([tabindex="-1"])');
    var out = [];
    for (var i = 0; i < all.length; i++) {
      var e = all[i];
      if (e.disabled || e.type === 'hidden' || e.tabIndex === -1) continue;
      var box = e.getBoundingClientRect();
      if (box.width <= 0 || box.height <= 0) continue;
      out.push(e);
    }
    return out;
  };
  s.clear = function () {
    if (s.el) s.el.classList.remove('do-x-tv-focus');
    return { ok: true };
  };
  s.reset = function () {
    s.clear();
    s.el = null;
    return { ok: true };
  };
  s.move = function (delta) {
    var items = s.items();
    if (!items.length) return { ok: false };
    var at = s.el ? items.indexOf(s.el) : -1;
    var next = at < 0 ? (delta > 0 ? 0 : items.length - 1) : at + delta;
    if (next < 0 || next >= items.length) return { ok: false };
    s.clear();
    s.el = items[next];
    s.el.classList.add('do-x-tv-focus');
    s.el.scrollIntoView({ block: 'center', inline: 'center' });
    try { s.el.focus({ preventScroll: true }); } catch (e) {}
    return { ok: true };
  };
  s.activate = function () {
    if (!s.el) return { type: 'none' };
    var tag = (s.el.tagName || '').toLowerCase();
    var type = (s.el.type || 'text').toLowerCase();
    var typed = tag === 'textarea'
        || (tag === 'input'
            && ['text', 'email', 'password', 'search', 'tel', 'url', 'number']
                .indexOf(type) >= 0);
    if (typed) {
      return {
        type: 'text',
        secret: type === 'password',
        value: s.el.value || '',
        label: s.el.getAttribute('aria-label')
            || s.el.getAttribute('placeholder')
            || s.el.getAttribute('name') || ''
      };
    }
    s.el.click();
    return { type: 'click' };
  };
  s.setValue = function (text) {
    if (!s.el) return { ok: false };
    // Through the prototype's own setter, so a page whose framework tracks
    // the field (every sign-in form is one) sees the change it is watching
    // for rather than a value that appears from nowhere.
    var proto = Object.getPrototypeOf(s.el);
    var desc = Object.getOwnPropertyDescriptor(proto, 'value');
    if (desc && desc.set) { desc.set.call(s.el, text); } else { s.el.value = text; }
    s.el.dispatchEvent(new Event('input', { bubbles: true }));
    s.el.dispatchEvent(new Event('change', { bubbles: true }));
    return { ok: true };
  };
})()
''';
