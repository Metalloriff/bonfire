# WIP
### NOTE: This page and project are work in progress. I'm currently focusing on the project itself, and only have this repo public for build testing purposes. If you wish to use Bonfire, you're absolutely free to do so, but please note that it's not ready for public testing yet.

# Bonfire
Bonfire is a privacy-based open source, cross-platform and self-hosted text and voice/video chat application with no centralized servers.

Bonfire puts the trust in the users, not a central authority. It can even be used offline on the local network. Your login data and settings are stored on your own device, and everything else is per-server.

# Philosophy
Corporations and governments have rendered privacy and security a distant dream. The days of the free internet are slipping away, and I wish to do my part in preserving it.

Privacy is a fundamental human right, but corporations and governments try to take it from us and convince us otherwise. We've let them get to the point of asking for ID verification to use basic chat services. F*ck that. Give the power back to the people.

We pay for slight conveniences, not only with our money, but with our dignity. In my eyes, hosting your own server is a small price to pay for peace of mind.

I've done everything in my power to make this project as easy as possible to host, and I hope for people to take that slight inconvenience and take back control of their privacy and data.

## Notable Features
- **No centralized servers.**
- **No mandatory third-party network connections.**
	- Any future third-party network connections will be 100% optional;
	- However, there are currently no third-party network connections and none are planned at the moment.
- **Password-protected servers.**
- **End-to-end encryption on private messages. (DMs)**
- **The ability to send password-protected messages and files.**
- **MCU-based voice/video chat.**
	- (video chat is not yet implemented)
- **The option to purge all of your messages and files when leaving a server.**
- **Built in the Godot engine, so you can easily mod and customize the client and server.**
- **Per-server profiles, completely detaching the server's knowledge of your identity.**
- **The ability to download files without opening a web browser first.**
	- (truly revolutionary technology)
- **Smooth animations and a responsive UI.**
	- No more freezing and lagging when interacting with the client.
- **Lightweight.**
	- While it's not the most lightweight chat client out there, it packs a punch for its small footprint, and easily runs smoother and lighter than every web-based client.
- **Per-server user IDs by default, maximizing privacy and security.**

## Missing Expected Features
Some of the features that are missing in Bonfire but may be expected from modern chat services, and the reasons:
- **ID verification**
	- Because F*ck that.
- **Push Notifications**
	- I've not yet been able to find a way to handle push notifications in Godot, especially a privacy-friendly solution. This is a high priority feature that I'm trying to find a solution for. If you have any leads, please create an issue or pull request.
- **Account/Settings Sync**
	- While your account will sync on servers, if you have the same username and password, you will have to change your settings between every device, and join all of your servers for every device.
	- There is the possibility of adding a "home server" in the future, that will sync your settings and servers across all devices. This is not a high priority currently, but please provide feedback if you would like this to be a higher priority.
- **Proper Mobile Support**
	- I will be fully honest, I suck at mobile development. I'm trying my best with this project, and it is a high priority, and even I plan to be using this as my exclusive chat client on my phone. If you have any suggestions, please create an issue or pull request.
	- Currently this biggest issue is the lack of background activity. Android has very strict policies on background activity, and I'm not sure how to handle it in Godot. When the app is in the background (or locked), voice chat stops working entirely. When going back to the foreground, it may take a few seconds for your servers to reconnect. Both of these are unacceptable issues.

## Screenshots
Coming soon.

## Server Setup
Currently, you can start a server with `./bonfire_executable --headless --server`, or via the in-app server hosting menu. More detailed information will be added to this section soon, along with server config descriptions.

# Basic Roadmap Stages
### 🔵 Private Testing, Stage 1 (CURRENT)
Builds are very infrequent and unstable. Anything may break at any time. Currently only accepting live testing via the Godot editor, as major changes are much more frequent than build outputs.

### ⚫ Private Testing, Stage 2 (SOON)
Builds are more frequent, still fairly unstable, but much more stable than stage 1. I plan to do days where me and my team of friends will be using Bonfire exclusively, and we will find and fix any issues that arise. Still not very usable for the general public, but major refactoring should be less common or non-existent.

### ⚫ Private/Public Testing, Stage 3
Builds are frequent and mildly stable. No major refactoring will occur, but I will not be advertising Bonfire to the public yet, but will encourage anyone who stumbles upon it to use it, along with sharing the project with more people in general.

### ⚫ Public Testing, Stage 4
Builds are frequent and mostly stable. I will be lightly advertising Bonfire to the public. By this stage, Bonfire should be me and my group's exclusive chat service.

### ⚫ Release, Stage 5
Bonfire is now public, and I will be advertising it to the public. At this stage, Bonfire should be a widely usable chat service with minimal issues. Updates will still be released frequently, but heavier internal testing will be done before major updates. Builds will also come as a release candidate version before each update.

## Security
Please note that this is my first project of this scale, and I'm not a security expert. I have made this project as secure as possible, but there are likely some security holes. If you find any, please let me know with an issue or pull request.

In general, I would recommend using this project with people you trust in its early stages, especially considering that is the project's primary purpose.

## Donations
If you'd like to support me, you can donate however is most convenient for you. Anything helps keep this project alive. Thank you! ❤️

### XMR
```
82qpTD6XmnKGLF9pMuJxmeBWVhkGEc76DNrPAPAKbATVPHL6TTRkV7RUvi7jD6rp27cCJKJ2oKDGiLFJSS8wxabn8CrWGgS
```
### LTC
```
ltc1q3erhn0mtnwcwjatuayv0mfwq4kh9y20vn4v3mk
```
### Ko-fi
https://ko-fi.com/metalloriff

## AI Usage
Since this is a big thing for a lot of people, I wish to remain as clear as possible. >99% of the code in this project is written by me, and anything that is AI-assisted is clearly marked as such with code comments. This is **NOT** a vibe-coded project.

# License
This project is licensed under the [Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/).