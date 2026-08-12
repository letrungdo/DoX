import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/services/movie_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/dialog/dialog_action_button.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:flutter/material.dart';

/// Big enough to hit comfortably while its shadow still clears the row.
const _actionButtonSize = 38.0;

/// Add / edit / pick the movie server the app talks to.
class MovieServerDialog extends StatefulWidget {
  final VoidCallback onServerChanged;

  const MovieServerDialog({super.key, required this.onServerChanged});

  @override
  State<MovieServerDialog> createState() => _MovieServerDialogState();
}

class _MovieServerDialogState extends State<MovieServerDialog> {
  late List<String> _servers;
  late String? _currentBaseUrl;
  late String? _primaryServer;

  final _urlController = TextEditingController();
  String? _editingUrl;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _loadServers() {
    _servers = movieService.getServers();
    _currentBaseUrl = movieService.baseUrl;
    _primaryServer = movieService.primaryServer;
  }

  void _refreshServers() {
    if (!mounted) return;
    setState(() {
      _loadServers();
    });
  }

  Future<void> _selectServer(String url) async {
    if (_isAdding || _editingUrl != null) return;
    if (url == _currentBaseUrl) return;
    await movieService.updateBaseUrl(url);
    widget.onServerChanged();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleSave() async {
    // `https://` is optional in the field; the service fills it in.
    final url = movieService.normalizeServerUrl(_urlController.text);
    if (url.isEmpty) return;

    if (_isAdding) {
      await movieService.updateBaseUrl(url);
    } else if (_editingUrl != null) {
      final isPrimary = movieService.isPrimary(_editingUrl);
      final servers = storageService.getMovieServers();
      final index = servers.indexOf(_editingUrl!);

      if (index != -1) {
        servers[index] = url;
        await storageService.setMovieServers(servers);
        if (isPrimary) {
          await storageService.setPrimaryMovieServer(url);
        }
        if (movieService.baseUrl == _editingUrl) {
          await movieService.updateBaseUrl(url);
        }
      }
    }

    setState(() {
      _isAdding = false;
      _editingUrl = null;
      _urlController.clear();
      _loadServers();
    });
    widget.onServerChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isInputMode = _isAdding || _editingUrl != null;

    return AppDialog(
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      titleWidget: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Expanded + ellipsis: a long localized title must not push the
          // add button out of the dialog.
          Expanded(
            child: Text(
              isInputMode
                  ? (_isAdding
                        ? l10n.addMovieServerUrl
                        : l10n.editMovieServerUrl)
                  : l10n.movieServerUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isInputMode)
            NeuIconButton(
              size: _actionButtonSize,
              iconSize: 20,
              depth: 0.4,
              icon: Icons.add_rounded,
              onPressed: () {
                setState(() {
                  _isAdding = true;
                  _urlController.clear();
                });
              },
            ),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isInputMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: _urlController,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: l10n.serverUrlHint,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      onPressed: _handleSave,
                    ),
                  ),
                  onSubmitted: (_) => _handleSave(),
                ),
              ),
            Flexible(
              child: _servers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(l10n.noServersFound),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _servers.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final url = _servers[index];
                        final isPrimary = url == _primaryServer;
                        final isSelected = url == _currentBaseUrl;
                        final isCurrentlyEditing = url == _editingUrl;

                        return ListTile(
                          enabled: !isInputMode,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          horizontalTitleGap: 8,
                          leading: Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : null,
                            size: 22,
                          ),
                          title: Text(
                            movieService.getLabelForUrl(url),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            url,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: isInputMode
                              ? (isCurrentlyEditing
                                    ? Icon(
                                        Icons.edit_note_rounded,
                                        color: context.colors.warning,
                                      )
                                    : null)
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 8,
                                  children: [
                                    // The primary server cannot be deleted, so
                                    // its row only keeps the edit button.
                                    if (!isPrimary)
                                      NeuIconButton(
                                        size: _actionButtonSize,
                                        iconSize: 20,
                                        depth: 0.4,
                                        color: theme.colorScheme.error,
                                        icon: Icons.delete_outline_rounded,
                                        onPressed: () async {
                                          await movieService.deleteServer(url);
                                          _refreshServers();
                                          if (isSelected) {
                                            widget.onServerChanged();
                                          }
                                        },
                                      ),
                                    NeuIconButton(
                                      size: _actionButtonSize,
                                      iconSize: 20,
                                      depth: 0.4,
                                      icon: Icons.edit_outlined,
                                      onPressed: () {
                                        setState(() {
                                          _editingUrl = url;
                                          _urlController.text = url;
                                          _isAdding = false;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                          onTap: () => _selectServer(url),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (isInputMode)
          DialogActionButton(
            text: l10n.cancel,
            kind: DialogActionKind.cancel,
            onPressed: () {
              setState(() {
                _isAdding = false;
                _editingUrl = null;
                _urlController.clear();
              });
            },
          )
        else
          DialogActionButton(
            text: l10n.close,
            kind: DialogActionKind.cancel,
            onPressed: () => Navigator.pop(context),
          ),
        if (isInputMode)
          DialogActionButton(text: l10n.save, onPressed: _handleSave),
      ],
    );
  }
}
