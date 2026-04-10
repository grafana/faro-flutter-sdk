import 'package:equatable/equatable.dart';
import 'package:faro_example/features/webview_handoff/domain/webview_handoff_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI state for the WebView tracing landing page.
class WebViewHandoffPageUiState extends Equatable {
  const WebViewHandoffPageUiState({required this.isConfigured});

  final bool isConfigured;

  @override
  List<Object?> get props => [isConfigured];
}

/// Actions available to the WebView tracing landing page.
abstract interface class WebViewHandoffPageActions {
  Uri getBaseUrl();
}

class _WebViewHandoffPageViewModel extends Notifier<WebViewHandoffPageUiState>
    implements WebViewHandoffPageActions {
  late WebViewHandoffService _service;

  @override
  WebViewHandoffPageUiState build() {
    _service = ref.watch(webViewHandoffServiceProvider);
    return WebViewHandoffPageUiState(isConfigured: _service.isConfigured);
  }

  @override
  Uri getBaseUrl() => _service.getBaseUrl();
}

final _webViewHandoffPageViewModelProvider =
    NotifierProvider<_WebViewHandoffPageViewModel, WebViewHandoffPageUiState>(
      _WebViewHandoffPageViewModel.new,
    );

final webViewHandoffPageUiStateProvider = Provider<WebViewHandoffPageUiState>((
  ref,
) {
  return ref.watch(_webViewHandoffPageViewModelProvider);
});

final webViewHandoffPageActionsProvider = Provider<WebViewHandoffPageActions>((
  ref,
) {
  return ref.read(_webViewHandoffPageViewModelProvider.notifier);
});
