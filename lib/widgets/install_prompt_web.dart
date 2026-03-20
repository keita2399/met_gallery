import 'dart:js_interop';

@JS('eval')
external JSAny? _eval(JSString code);

/// Initialize PWA install prompt listener (call once at app start)
void initInstallPrompt() {
  _eval('''
    window._pwaPrompt = null;
    window.addEventListener("beforeinstallprompt", function(e) {
      e.preventDefault();
      window._pwaPrompt = e;
    });
  '''.toJS);
}

/// Check if running as installed PWA
bool isRunningAsPwa() {
  final result = _eval('window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true'.toJS);
  if (result == null) return false;
  return (result as JSBoolean).toDart;
}

/// Check if iOS Safari
bool isIosSafari() {
  final result = _eval('(/iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream)'.toJS);
  if (result == null) return false;
  return (result as JSBoolean).toDart;
}

/// スプラッシュ画面を削除
void removeSplash() {
  _eval('if(typeof removeSplashFromWeb==="function")removeSplashFromWeb()'.toJS);
}

/// Trigger the install prompt (Chrome/Edge only)
void triggerInstallPrompt() {
  _eval('''
    if (window._pwaPrompt) {
      window._pwaPrompt.prompt();
      window._pwaPrompt = null;
    }
  '''.toJS);
}
