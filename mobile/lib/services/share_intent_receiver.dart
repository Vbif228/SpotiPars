import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../core/spotify/spotify_scraper.dart';

class ShareIntentReceiver {
  StreamSubscription? _intentSub;

  void initialize({required void Function(String spotifyUrl) onLinkReceived}) {
    // 1. Listen for incoming intents while app is running in background or foreground
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        for (final item in value) {
          _handleIncomingText(item.path, onLinkReceived);
        }
      },
      onError: (err) {
        debugPrint('Error listening to sharing intent: $err');
      },
    );

    // 2. Handle intent that opened the app from a terminated state
    ReceiveSharingIntent.instance.getInitialMedia().then(
      (List<SharedMediaFile> value) {
        for (final item in value) {
          _handleIncomingText(item.path, onLinkReceived);
        }
        ReceiveSharingIntent.instance.reset();
      },
    ).catchError((err) {
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
