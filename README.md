# GAM Admin — Aircall IT

A native macOS app for managing Google Workspace users and groups via [GAMADV-XTD3](https://github.com/GAM-team/GAM). Built for Aircall IT — runs locally with Touch ID authentication and no browser required.

![App by GMO 2026](https://img.shields.io/badge/App%20by-GMO%202026-002620?style=flat-square)

---

## What it does

| Section | Actions |
|---|---|
| **Offboarding** | Suspend account → transfer Drive → transfer calendar → set OOO in one click |
| **Transfer Drive** | Move all Drive files from one user to another |
| **File Search & Transfer** | Search files by name, select, and transfer ownership |
| **Shared Drives** | List all Shared Drives a user has access to |
| **Transfer Calendar** | Grant owner access on any calendar to a new user |
| **Out of Office** | Enable or disable vacation auto-reply for any user |
| **Delegate Mailbox** | Give a user read/send-as access to another mailbox |
| **User Lookup** | View full details — status, org unit, last login, aliases |
| **Suspend / Unsuspend** | Immediately block or restore account access |
| **Reset Password** | Generate a random password and force change on next login |
| **Update Profile** | Update display name, job title, or department |
| **Add to Group** | Add a user to a Google Group |
| **Remove from Group** | Remove a user from a specific group |
| **List Groups** | See all Google Groups a user belongs to |
| **Remove from All Groups** | Remove a user from every group (great for offboarding) |
| **Custom Command** | Run any read-only GAM command directly |

---

## Prerequisites

### 1. Python 3.11+
Check if you have it:
```bash
python3 --version
```
If not, download from [python.org](https://www.python.org/downloads/).

### 2. GAMADV-XTD3
This app is a UI layer on top of GAM. You need GAM installed and authorised with your Google Workspace admin account.

**Install GAM:**
```bash
bash <(curl -s -S -L https://raw.githubusercontent.com/GAM-team/GAM/master/gam-install.sh)
```
Full guide: [github.com/GAM-team/GAM/wiki/How-to-Install-Advanced-GAM](https://github.com/GAM-team/GAM/wiki/How-to-Install-Advanced-GAM)

**Authorise GAM** (first time only):
```bash
gam oauth create
gam user your-admin@yourdomain.com check serviceaccount
```
Follow the prompts — it will open a browser to authorise your Google admin account.

---

## Installation

```bash
git clone https://github.com/capellan85/gam-admin.git
cd gam-admin
./install.sh
```

That's it. `install.sh` will:
- Verify Python 3.11+ is installed
- Check GAM is reachable and show its version
- Create a Python virtual environment (`.venv/`)
- Install all dependencies

---

## Running the app

```bash
.venv/bin/python app.py
```

The app will prompt for Touch ID or your macOS login password before opening. The window runs locally — no data leaves your machine.

---

## Building a shareable .app bundle

To create a native `IT Admin.app` you can share with colleagues via Slack or AirDrop:

```bash
./build_app.sh
```

This creates `~/Applications/IT Admin.app` with the Aircall icon. To share it:

```bash
ditto -c -k --sequesterRsrc ~/Applications/IT\ Admin.app ~/Desktop/IT\ Admin.zip
```

Send the zip — the recipient drags it to `/Applications` and double-clicks. On first launch it may take ~30 seconds to set up Python if the bundled environment needs rebuilding.

> **Note:** each person still needs their own GAM install and OAuth credentials. The app will show a warning and link to the install guide if GAM is not found.

---

## Updating

```bash
git pull
```

No need to re-run `install.sh` unless dependencies change.

---

## Troubleshooting

**"GAM not found" warning in the app**
GAM is not installed or not on your PATH. Install it using the link above, then restart the app.

**Touch ID prompt doesn't appear**
Make sure the app is run directly (`python app.py`), not via `uvicorn` or another server.

**Command timed out**
Some GAM operations (large Drive transfers) can take over a minute. Try running the command directly in your terminal for more verbose output:
```bash
~/bin/gam7/gam user someone@domain.com transfer drive manager@domain.com
```

**Groups show 0 results**
External or guest accounts (`ext-` prefix) may not belong to any Google Groups — this is expected.

---

## Tech stack

- [FastAPI](https://fastapi.tiangolo.com/) — local REST API
- [pywebview](https://pywebview.flowrl.com/) — native macOS WebKit window
- [pyobjc](https://pyobjc.readthedocs.io/) — Touch ID via LocalAuthentication
- [GAMADV-XTD3](https://github.com/GAM-team/GAM) — Google Workspace CLI

---

*App by GMO 2026*
