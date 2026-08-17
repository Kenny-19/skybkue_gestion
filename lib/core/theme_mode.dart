import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mode d'affichage global : clair ou sombre.
/// (Persistance disque à venir — pour l'instant en mémoire.)
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.light);
