/// Internal umbrella barrel shared by the package's `src` implementation files.
///
/// This is NOT part of the public API — it re-exports the third-party
/// dependencies and internal declarations that the implementation relies on so
/// each `src` file only needs a single import. Consumers should import
/// `package:livelyness_detection/livelyness_detection.dart` instead.
library;

export 'dart:convert';
export 'dart:io';
export 'dart:math';

export 'package:animate_do/animate_do.dart';
export 'package:camerawesome/camerawesome_plugin.dart';
export 'package:camerawesome/pigeon.dart';
export 'package:equatable/equatable.dart';
export 'package:flutter/foundation.dart';
export 'package:flutter/material.dart';
export 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
export 'package:lottie/lottie.dart';
export 'package:path_provider/path_provider.dart';
export 'package:rxdart/rxdart.dart';
export 'package:uuid/uuid.dart';

export 'index.dart';
