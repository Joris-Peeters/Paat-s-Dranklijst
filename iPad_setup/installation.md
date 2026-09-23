# iPad installation guide

I don't have an Apple developer account, so the provided IPA is unsigned and can only be installed using a tool such as [TrollStore](https://github.com/opa334/TrollStore).

I used an *iPad Air 2* because they are very cheap on the second-hand market and they work great. This guide might also work for other old iPads. See [Installing TrollStore](https://ios.cfw.guide/installing-trollstore/) to see which devices are supported.

This guide sets up supervision on the iPad to enable **Single App Mode**. *Guided Access* is an alternative way to get a kiosk experience but is less robust.

Everything is done from a Linux machine with [pymobiledevice3](https://github.com/doronz88/pymobiledevice3). Apple Configurator, the usual way to supervise a device, is macOS-only and is not needed here.

This guide will help you:

- Restore (wipe) a second hand iPad
- Create an organization keybag
- Supervise it
- Install TrollStore
- Install the app
- Enable Single App Mode
- Exit single App Mode

---

## Before you start

You need:

- A Linux machine and a **data** USB cable (many cheap cables only carry power).
- The iPad, with **Activation Lock off**. Ask the seller to sign out, or on the
  iPad go to *Settings → [your name] → Find My → Find My iPad → off*. If the
  iPad is still tied to somebody's Apple Account, nothing below will work.

Two warnings worth reading now:

- **Supervising wipes the iPad.** Do this before putting anything on it.
- **The keybag you create in step 4 is the only key to this iPad.** Back it up
  somewhere safe. Lose it and the only way to change the configuration again is
  to erase the iPad and start over.

## 1. Set up the Linux machine

`usbmuxd` is the daemon that talks to iOS devices over USB. Install it from your
distribution and make sure it is running:

```bash
sudo pacman -S usbmuxd            # Arch
sudo apt install usbmuxd          # Debian / Ubuntu

sudo systemctl enable --now usbmuxd
```

Install `pymobiledevice3` in its own virtual environment, so it does not touch
the system Python:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -U pymobiledevice3

pymobiledevice3 version
```

Every `pymobiledevice3` command below needs that environment active. In a new
terminal, run the `source` line again first.

## 2. Connect the iPad

Plug the iPad in and check it is seen:

```bash
pymobiledevice3 usbmux list
```

The iPad asks *Trust This Computer?* — unlock it and tap **Trust**, then pair:

```bash
pymobiledevice3 lockdown pair
```

Now read the device details:

```bash
pymobiledevice3 lockdown info
```

Note down `ProductType` (e.g. `iPad5,3` for an iPad Air 2) and `ProductVersion`
(the iOS version). You need both to pick the right TrollStore method later.

## 3. Erase the iPad

A second-hand iPad should be wiped before it becomes a kiosk. The simplest way
is on the iPad itself:

> *Settings → General → Transfer or Reset iPad → Erase All Content and Settings*

If you would rather install a clean iOS at the same time, download an `.ipsw`
for your exact `ProductType` and restore over USB instead:

```bash
pymobiledevice3 restore update --ipsw ./iPad_64bit_12.5.7_16H81_Restore.ipsw --erase
```

The `.ipsw` must match the `ProductType` from step 2 and must still be signed by
Apple, otherwise the restore is refused.

**Stop at the "Hello" screen.** Do not tap through the setup assistant — the
next steps need the iPad exactly there.

## 4. Create the organization keybag

The keybag is your supervision identity: one PEM file holding a private key and
a self-signed certificate. The iPad will trust whoever holds it.

```bash
pymobiledevice3 profile create-keybag DranklijstOrganization.keybag "DranklijstOrganization"
```

Use your own group's name. **Copy this file somewhere safe** — a password
manager, an encrypted USB stick, anywhere that is not the machine you are
working on. Without it you cannot install or remove configuration profiles on
this iPad any more, and never commit it to a repository.

## 5. Supervise the iPad

With the iPad still on the "Hello" screen:

```bash
pymobiledevice3 profile supervise "DranklijstOrganization" --keybag DranklijstOrganization.keybag
```

Use the same organization name as in step 4. This one command:

- activates the iPad if it is not activated yet,
- marks it as supervised by your organization,
- registers the keybag's certificate as a supervisor certificate,
- skips every setup-assistant pane, so the iPad lands straight on the home screen.

Passing `--keybag` matters. Without it the command makes a throwaway keybag,
supervises with that, and then deletes it — leaving you locked out of your own
iPad.

Check that it worked:

```bash
pymobiledevice3 profile cloud-configuration
```

`IsSupervised` should be `true`. On the iPad, *Settings → General → About* now
says the iPad is supervised by your organization.

Join the Wi-Fi network on the iPad now; the next step needs it.

## 6. Install TrollStore and the app

Follow [ios.cfw.guide](https://ios.cfw.guide/installing-trollstore/) for your
iOS version — the method differs per version and is covered better there than it
could be here.

Once TrollStore is installed, download the `.ipa` from the
[Releases](https://github.com/Joris-Peeters/Paat-s-Dranklijst/releases) page and
open it with TrollStore to install it.

Getting the file onto the iPad is easiest by serving it from the same machine.
With the iPad on the same Wi-Fi network, run this in the folder holding the
`.ipa`:

```bash
python -m http.server 8000
```

Find the machine's address with `ip -4 addr` (or `hostname -I`), then open
`http://<that-address>:8000/` in Safari on the iPad and tap the `.ipa`. Safari
downloads it; install it using TrollStore.
Stop the server with `Ctrl+C` when you are done.

Then **launch the app, finish the first-run wizard, and test it a bit** before
Single App Mode is enabled. If you want to import data from a csv, this would also be the right time.

### Settings to decide on now

Once Single App Mode is on, the iPad's own *Settings* app is out of reach
without removing the profile again, so make these choices before step 7. The
app's own settings stay reachable behind the admin PIN.

**The screen.** There are two ways to stop the iPad sitting at full brightness
all day, and they combine:

- *Settings → Display & Brightness → Auto-Lock* decides whether iOS blanks the
  screen itself. **Never** keeps the app permanently visible, which is the
  reason for the `DisableAutoLock` option in the next step. A timeout instead
  means somebody has to wake the iPad with the home button before they can tap
  anything — if you go that way, leave `DisableAutoLock` off in step 7, since
  the profile option overrides this setting.
- The app can dim its own backlight after a long idle and bring it back on the
  first touch, under *Dim the screen when idle* in **Admin** in the app's own
  settings. It keeps the app on screen and reachable in one tap, at the cost of
  the panel never fully turning off. This one can still be changed later,
  without touching the profile.

The second options is recommended because waking it with a single tap on the screen is faster then pressing the home button twice (to wake and unlock) for a kiosk app.

Running both is fine: pick a dim delay well under the auto-lock timeout, or set
Auto-Lock to Never and let the app do the dimming on its own.

**Auto-brightness** (*Settings → Accessibility → Display & Text Size* on iOS 15) is
likewise a judgement call. The app has dark mode so setting the brightness to the
maximum is a valid option.

Keep the iPad on its charger, and leave Low Power Mode off.

## 7. Generate the App Lock profile

`make_applock_profile.py` (next to this file) asks what to lock down and writes
the profile. It only writes a file, so any Python 3 will do:

```bash
python make_applock_profile.py
```

The defaults are the ones you want for a fridge tablet. What each answer sets:

| Question | Payload key | Default |
| --- | --- | --- |
| Keep the screen on | `DisableAutoLock` | yes |
| Disable the sleep/wake button | `DisableSleepWakeButton` | yes |
| Lock the orientation | `DisableDeviceRotation` | yes |
| Disable the volume buttons | `DisableVolumeButtons` | yes |
| Disable the ringer/mute switch | `DisableRingerSwitch` | yes |

It writes `applock.mobileconfig` next to itself.

## 8. Enter Single App Mode

```bash
pymobiledevice3 profile install applock.mobileconfig --keybag DranklijstOrganization.keybag
```

With the keybag the profile installs silently — no tapping on the iPad. It
switches to the app immediately and goes back to it on every wake and every
reboot.

Check what is installed:

```bash
pymobiledevice3 profile list
```

## 9. Changing the options later

Run the generator again and install the result. The profile identifier stays the
same, so installing it replaces the one on the iPad; there is no need to remove
anything first.

```bash
python make_applock_profile.py
pymobiledevice3 profile install applock.mobileconfig --keybag DranklijstOrganization.keybag
```

## 10. Exit Single App Mode

```bash
pymobiledevice3 profile remove xyz.jpsystems.paatsDranklijst.applock
```

You can now exit the app again, move backup files around, change system settings, or anything else.
It stays supervised — that is a separate thing, and undoing it means erasing the iPad.
