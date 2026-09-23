#!/usr/bin/env python3
"""Generate an App Lock (Single App Mode) configuration profile for an iPad.

Asks a handful of questions and writes applock.mobileconfig. It never talks to
the iPad; install the result with:

    pymobiledevice3 profile install applock.mobileconfig --keybag your.keybag
"""

import plistlib
import uuid

BUNDLE_ID = "xyz.jpsystems.paatsDranklijst"
ORGANIZATION = "DranklijstOrganization"
OUTPUT = "applock.mobileconfig"

# Settings the person at the iPad cannot change. Apple defaults every one of
# these to false, so only the ones answered "yes" are written.
LOCK_OPTIONS = [
    ("DisableAutoLock", "Keep the screen on (disable auto-lock)"),
    ("DisableSleepWakeButton", "Disable the sleep/wake button"),
    ("DisableDeviceRotation", "Lock the orientation (disable rotation sensing)"),
    ("DisableVolumeButtons", "Disable the volume buttons"),
    ("DisableRingerSwitch", "Disable the ringer/mute switch"),
]


def ask(prompt: str, default: str) -> str:
    """Ask for a line of text. Empty input, or no input at all, takes the default."""
    try:
        return input(f"{prompt} [{default}]: ").strip() or default
    except EOFError:
        print()
        return default


def ask_bool(prompt: str) -> bool:
    """Ask a yes/no question, defaulting to yes, until the answer is one of them."""
    while True:
        try:
            answer = input(f"{prompt}? [Y/n]: ").strip().lower()
        except EOFError:
            print()
            return True
        if answer in ("", "y", "yes"):
            return True
        if answer in ("n", "no"):
            return False
        print("  Please answer y or n.")


def main() -> None:
    print("App Lock profile generator — press Enter to take the default.\n")
    bundle_id = ask("App bundle identifier", BUNDLE_ID)
    organization = ask("Organization (same as the supervision one)", ORGANIZATION)
    print()

    options = {key: True for key, prompt in LOCK_OPTIONS if ask_bool(prompt)}

    profile = {
        "PayloadContent": [
            {
                "App": {"Identifier": bundle_id, "Options": options},
                "PayloadType": "com.apple.app.lock",
                "PayloadIdentifier": f"{bundle_id}.applock.payload",
                "PayloadUUID": str(uuid.uuid4()),
                "PayloadVersion": 1,
                "PayloadDisplayName": "Single App Mode",
                "PayloadOrganization": organization,
            }
        ],
        "PayloadType": "Configuration",
        # Stable across runs: installing the same identifier replaces the
        # installed profile instead of adding a second one.
        "PayloadIdentifier": f"{bundle_id}.applock",
        "PayloadUUID": str(uuid.uuid4()),
        "PayloadVersion": 1,
        "PayloadDisplayName": "Single App Mode",
        "PayloadDescription": f"Locks this device to {bundle_id}.",
        "PayloadOrganization": organization,
    }

    with open(OUTPUT, "wb") as file:
        plistlib.dump(profile, file, fmt=plistlib.FMT_XML)

    print(f"\nWrote {OUTPUT}")
    print(f"  locked to: {bundle_id}")
    print(f"  options:   {', '.join(sorted(options)) or 'none'}")
    print("\nInstall it with:")
    print(f"  pymobiledevice3 profile install {OUTPUT} --keybag your.keybag")


if __name__ == "__main__":
    main()
