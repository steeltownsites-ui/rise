# Rise

A personal wake-up alarm for iPhone, in the style of Wayk/SnoozeOff. You switch the alarm off by finishing a mission.

## Features
- **Real alarms** with Apple's AlarmKit (iOS 26+): they ring on the lock screen and in silent mode, like the Clock app.
- **Missions:** Push Ups and Squats (counted live by the front camera), Math (easy/medium/hard), Object Hunt (with Respin), Sky Photo, Make Bed (photos checked on the phone with Apple's image recognition), Affirmation.
- **Back-up alarm:** tapping the alarm opens the mission and arms another alarm 3 minutes later. Only finishing the mission cancels it.
- **Sounds:** six built-in sounds (Ultra Loud Siren, Classic Beep, Digital Alarm, Rising Tone, Morning Chime, Bass Pulse) or your own songs (MP3/M4A/WAV, 30-second clip). The sound keeps playing in the app until math and affirmation missions are done.
- **Home:** "rings in" countdown, Track sleep, mission alarms, streak, today's wake-up.
- **Insights:** wake-up time chart, streaks, average sleep, mission counts, recent mornings.
- Hold 15 s to skip a day.

## How it gets built
Every push to `main` builds an unsigned `Rise.ipa` on GitHub Actions (macOS 26) and attaches it to a new Release.

## Installing without a Mac or a paid account
1. On any Windows PC or Mac, install **Sideloadly** (sideloadly.io) and iTunes/Apple Devices for Windows.
2. Download `Rise.ipa` from the latest Release.
3. Plug in the iPhone, drag the IPA into Sideloadly, enter your Apple ID and press Start.
4. On the iPhone: Settings → General → VPN & Device Management → trust your Apple ID. Turn on Developer Mode if asked (Settings → Privacy & Security).
5. Free Apple ID installs last 7 days. Refresh with Sideloadly (it can do it automatically over Wi-Fi), or set up SideStore to refresh from the phone.
