import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object> get props => [];
}

class ToggleTheme extends ThemeEvent {}

class SetThemeMode extends ThemeEvent {
  final ThemeMode mode;
  const SetThemeMode(this.mode);

  @override
  List<Object> get props => [mode];
}
