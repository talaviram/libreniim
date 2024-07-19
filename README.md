## LibreNiim

Open-source, end user, privacy focused printing app(s) for [Niimbot](https://www.niimbot.net) label printers.

It all started when I bought a D110 just to discover the appstore apps (iOS and Android) got in-app purchase built-into them which already got me wondering.
Then when trying to install it an old Android phone with custom rom, it complained it is rooted and didn't agree to run...

At this point, I've looked for open-source alternatives.

I was happy to discover some projects.
As other projects, this is mostly a port of [kjy00302/niimprint](https://github.com/kjy00302/niimprint) and [AndBondStyle/niimprint](https://github.com/AndBondStyle/niimprint).

Other notable projects:
https://github.com/ayufan/niimprint-web
https://github.com/dtgreene/niimbotjs/tree/main

Based on the APIs shown by those projects I've did some Swift port bundled in a simple label app. It uses [AsyncBluetooth](https://github.com/manolofdez/AsyncBluetooth) to abstract CoreBluetooth.

## Apps

Currently there is a Catalyst/SwiftUI app that can run on iOS, iPadOS and macOS.

I didn't test it on anything but the D110 I have.
So feedback and PRs are appreciated.

![Label Editor View](images/libreniim_label.png)
![Scan View](images/libreniim_scanning.png)
![Connecting View](images/libreniim_connecting.png)
![Info View](images/libreniim_info.png)

[Privacy](PRIVACY.md)