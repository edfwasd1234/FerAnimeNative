import React from "react";
import { WebView, WebViewProps } from "react-native-webview";
import { adBlockerInjectedJavaScript, mediaSnifferInjectedJavaScript, shouldAllowWebViewRequest } from "./adBlocker";

export function AdBlockedWebView(props: WebViewProps) {
  return (
    <WebView
      {...props}
      javaScriptEnabled
      domStorageEnabled
      setSupportMultipleWindows={false}
      onShouldStartLoadWithRequest={(request) => {
        const parentDecision = props.onShouldStartLoadWithRequest?.(request) ?? true;
        return parentDecision && shouldAllowWebViewRequest(request);
      }}
      injectedJavaScriptBeforeContentLoaded={`${adBlockerInjectedJavaScript}\n${mediaSnifferInjectedJavaScript}\n${props.injectedJavaScriptBeforeContentLoaded || ""}`}
      injectedJavaScript={`${adBlockerInjectedJavaScript}\n${mediaSnifferInjectedJavaScript}\n${props.injectedJavaScript || ""}`}
    />
  );
}
