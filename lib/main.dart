import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(WebViewExample());
}

class WebViewExample extends StatefulWidget {
  @override
  WebViewExampleState createState() => WebViewExampleState();
}

class WebViewExampleState extends State<WebViewExample> {
  WebViewController _controller;

  @override
  void initState() {
    super.initState();
    // Enable hybrid composition.
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
  }

  @override
  Widget build(BuildContext context) {
    return WebView(
      initialUrl: "about:blank",
      javascriptMode: JavascriptMode.unrestricted,
      onWebViewCreated: (WebViewController webViewController) {
        _controller = webViewController;
        _loadWelect(context);
      },
      onPageStarted: (Void) {
        injectWelectMessageListener(_controller, context);
      },
      javascriptChannels: <JavascriptChannel>[
        _welectJavascriptChannel(context),
      ].toSet(),
    );
  }

  JavascriptChannel _welectJavascriptChannel(BuildContext context) {
    // register a JavascriptChannel so we can receive messages from the welect process
    return JavascriptChannel(
        name: 'Welect',
        onMessageReceived: (JavascriptMessage message) {
          var eventData = jsonDecode(message.message);
          switch (eventData['type']) {
            // if this event has been received the user watched a video successfully
            // the token can be configured to be valid for a specific time by welect
            // you can check wether the token is valid or not by calling:
            // https://www.welect.de/api/v1/lease_token/${token} (return {valid: true | false})
            case "welect:payload":
              print('process finished, token: ${eventData['payload']}');
              break;
            case "cancel":
              print("an error occured, process could not be finished");
              break;
            default:
          }
        });
  }

  _loadWelect(BuildContext context) async {
    const externalId = "TjB6rd0Q9hU4Na4jQa9bFGWaV85e";
    // see if welect is available by doing a preflight check.
    // response looks like this:
    // {available: true | false, entry_url: "url_to_welect"}
    // body can be empty or contain the gdpr object given by the tcf-api (gdpr_consent: tcf-object)
    var response = await http
        .post('https://www.welect.de/api/v2/preflight/${externalId}', body: {});
    var responseJSON = jsonDecode(response.body);
    // TODO: proper error handling
    if (responseJSON['available']) {
      _controller.loadUrl(responseJSON['entry_url']);
    }
  }

  void injectWelectMessageListener(
      WebViewController controller, BuildContext context) async {
    // apparently the webview plugin is not able to directly access the messages posted to window.
    // thus we have to add the event listener manually and forward events to the registered JavascriptChannel
    await controller.evaluateJavascript(
        "window.addEventListener('message', (event) => { Welect.postMessage(JSON.stringify(event.data)); }, true);");
  }
}
