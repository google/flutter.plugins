## 2.1.1 - 21 Oct 2022
  * Fix issue with starting MediaSessionCompat

## 2.1.0 - 08 Nov 2021
  * Android service: move startForeground into onStartCommand
  * Android S fixes for PendingIntent

## 2.0.1 - 27 May 2021
  * Fix null safety bugs with platform media buttons.
  * Update example app to null safety.

## 2.0.0 - 10 March 2021
  * Migrate to null safety.

## 1.3.3 - 6 Feb 2021
  * Fix asset loading issue on Android.
  * Fix foreground notification issue on Android.

## 1.3.2 - 11 August 2020
  * Fix notification stop/restart issue on Android.

## 1.3.1 - 23 May 2020
  * Fix null pointer issues on Android.

## 1.3.0 - 27 Mar 2020
  * Migrate to Android v2 embedding.

## 1.2.0 - 28 Dec 2019
  * Add loading audio from local files, via Audio.loadFromAbsolutePath().

## 1.1.1 - 28 Dec 2019
  * README tweaks.

## 1.1.0 - 24 Dec 2019
  * Proper background audio on Android (using MediaBrowserService).
  * Caller can set supported media actions, metadata, and Android notification buttons.
  * Minor breaking change: 'shouldPlayInBackground' static flag is removed, and a per-Audio 'playInBackground' flag is
    used on each Audio load.
  * Expanded documentation.

## 1.0.3 - 2 Dec 2019

  * Support older versions of Android.
  * Fix error handling in Dart lib, so failed loads get cleaned up before calling onError().

## 1.0.2 - 21 Nov 2019

  * Fix background audio on iOS, add ability to specify iOS audio category (which defaults to 'playback').

## 1.0.1 - 21 Nov 2019

  * Fix new build issues in podfile, add pubspec.yaml dependency versions

## 1.0.0 - 7 Nov 2019

  * Initial open source release
