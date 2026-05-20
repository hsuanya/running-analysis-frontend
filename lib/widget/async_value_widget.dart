import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.error,
    this.loading = const Center(child: CircularProgressIndicator()),
  });
  final AsyncValue<T> value;
  final Widget Function(T) data;
  final Widget Function(Object, StackTrace)? error;
  final Widget loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      error: error ?? (e, st) => Center(child: Text(e.toString())),
      loading: () => loading,
    );
  }
}
