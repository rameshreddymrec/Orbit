/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * BlackHole is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with BlackHole.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * Copyright (c) 2021-2023, Ankit Sangwan
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class TiltWrapper extends StatefulWidget {
  final Widget child;
  final double maxAngle;
  final bool enableTilt;

  const TiltWrapper({
    super.key,
    required this.child,
    this.maxAngle = 0.1,
    this.enableTilt = true,
  });

  @override
  State<TiltWrapper> createState() => _TiltWrapperState();
}

class _TiltWrapperState extends State<TiltWrapper> {
  double _x = 0.0;
  double _y = 0.0;
  StreamSubscription<AccelerometerEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    if (widget.enableTilt) {
      _subscription = accelerometerEventStream().listen((AccelerometerEvent event) {
        setState(() {
          // Normalize the values to [-1, 1] range roughly
          // Accelerometer values are usually around -10 to 10
          _x = (event.x / 10).clamp(-1.0, 1.0);
          _y = (event.y / 10).clamp(-1.0, 1.0);
        });
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enableTilt) return widget.child;

    return TweenAnimationBuilder<Offset>(
      duration: const Duration(milliseconds: 200),
      tween: Tween<Offset>(
        begin: Offset.zero,
        end: Offset(_x, _y),
      ),
      builder: (context, offset, child) {
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateX(offset.dy * widget.maxAngle)
            ..rotateY(-offset.dx * widget.maxAngle),
          alignment: FractionalOffset.center,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
