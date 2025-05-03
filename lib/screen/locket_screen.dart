import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/screen/core/app_scaffold.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/view_model/locket_view_model.dart';
import 'package:do_x/widgets/text_field.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class LocketScreen extends StatefulScreen implements AutoRouteWrapper {
  const LocketScreen({super.key});

  @override
  State<LocketScreen> createState() => _HomeScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocketViewModel(), //
      child: this,
    );
  }
}

class _HomeScreenState<V extends LocketViewModel> extends ScreenState<LocketScreen, V> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final profilePicture = appData.user?.profilePicture;
    return AppScaffold(
      appBar: AppBar(
        leadingWidth: 100,
        leading: CircleAvatar(
          backgroundImage: profilePicture != null ? NetworkImage(profilePicture) : null, //
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20), //
              child: _buildBody(),
            ),
            Positioned(
              top: 7,
              left: 0,
              right: 0,
              child: Selector<V, bool>(
                selector: (p0, p1) => p1.isUploading,
                builder: (context, isUploading, _) {
                  return Visibility(
                    visible: isUploading, //
                    child: LinearProgressIndicator(
                      // backgroundColor: Colors.grey.withValues(alpha: 0.5), //
                    ),
                  );
                },
              ),
            ),
          ],
        ), //
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        SizedBox(height: 20),
        Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return Selector<V, Uint8List?>(
                  selector: (p0, p1) => p1.croppedImage,
                  builder: (context, data, _) {
                    return Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20), //
                        color: Colors.grey,
                      ),
                      alignment: Alignment.center,
                      height: constraints.maxWidth, //
                      child: data == null ? SizedBox.expand() : Image.memory(data),
                    );
                  },
                );
              },
            ),
            Positioned(
              bottom: 10,
              left: 20,
              right: 20,
              child: Selector<V, String?>(
                selector: (p0, p1) => p1.caption,
                builder: (context, caption, _) {
                  return Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white70, //
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IntrinsicWidth(
                        child: DoTextField(
                          value: caption, //
                          decoration: InputDecoration(
                            isDense: true, // Remove the default content padding.
                            contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                            hintText: caption.isNullOrEmpty ? "Input your caption" : null, //
                            border: InputBorder.none,
                          ),
                          textAlign: TextAlign.center,
                          onChanged: vm.onCaptionChanged,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        SizedBox(height: 10),

        Selector<V, bool>(
          selector: (p0, p1) => p1.isUploading,
          builder: (context, isUploading, _) {
            return ElevatedButton(
              onPressed: isUploading ? null : () => vm.pickMedia(), //
              child: Text('Select Media'),
            );
          },
        ),
        SizedBox(height: 32),
        Selector<V, bool>(
          selector: (p0, p1) => p1.isUploading || p1.croppedImage == null,
          builder: (context, isDisable, _) {
            return ElevatedButton(
              onPressed: isDisable ? null : () => vm.startUpload(), //
              child: Text('Upload'),
            );
          },
        ),
      ],
    );
  }
}
