import 'package:flutter/material.dart';

/// App-wide route observers registered with [MaterialApp.navigatorObservers].
///
/// Each observer is keyed to a specific screen that needs push-notification
/// for transient UI cleanup (e.g. dismissing route-local snackbars).
final RouteObserver<ModalRoute<void>> addLineRouteObserver =
    RouteObserver<ModalRoute<void>>();
