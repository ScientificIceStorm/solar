import 'package:flutter/widgets.dart';

import 'app_session_controller.dart';

class SolarAppScope extends InheritedNotifier<AppSessionController> {
  const SolarAppScope({
    required AppSessionController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppSessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SolarAppScope>();
    assert(scope != null, 'SolarAppScope is missing from the widget tree.');
    return scope!.notifier!;
  }
}
