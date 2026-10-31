import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../spotify/spotify_scraper.dart';

class ShareIntentReceiver {
  StreamSubscription? _intentSub;

  void initialize({required void Function(String spotifyUrl) onLinkReceived}) {
    // 1. Listen for incoming intents while app is running in background or foreground
    _intentSub = ReceiveSharingIntent.getTextStream().listen((String value) {
      _handleIncomingText(value, onLinkReceived);
    }, onError: (err) {
      debugPrint('Error listening to sharing intent: $err');
    });

    // 2. Handle intent that opened the app from a terminated state
    ReceiveSharingIntent.getInitialText().then((String? value) {
      if (value != null && value.isNotEmpty) {
        _handleIncomingText(value, onLinkReceived);
      }
    }).catchError((err) {
      debugPrint('Error getting initial sharing intent: $err');
    });
  }

  void _handleIncomingText(
    String text,
    void Function(String spotifyUrl) onLinkReceived,
  ) {
    if (text.isEmpty) return;

    // Check if shared text contains a valid Spotify URL
    final parsed = SpotifyScraper.parseUrl(text);
    if (parsed != null) {
      onLinkReceived(text.trim());
    }
  }

  void dispose() {
    _intentSub?.cancel();
  }
}
