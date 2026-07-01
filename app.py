import sys
import threading
import time
import urllib.request
import uvicorn
import webview
from auth import authenticate
from main import app as fastapi_app, GAM

PORT = 58432
URL = f"http://localhost:{PORT}"


def set_app_name():
    try:
        from Foundation import NSBundle
        info = NSBundle.mainBundle().infoDictionary()
        if info:
            info["CFBundleName"] = "GAM Admin"
            info["CFBundleDisplayName"] = "GAM Admin"
    except Exception:
        pass


def gam_alert():
    """Show a native macOS alert if GAM is not found, then exit."""
    try:
        from AppKit import NSAlert, NSCriticalAlertStyle, NSApp
        from Foundation import NSRunLoop, NSDefaultRunLoopMode, NSDate
        import objc

        alert = NSAlert.alloc().init()
        alert.setMessageText_("GAM Not Found")
        alert.setInformativeText_(
            "GAMADV-XTD3 (gam) could not be found on this system.\n\n"
            "Please install it from:\nhttps://github.com/GAM-team/GAM/wiki/How-to-Install-Advanced-GAM\n\n"
            "After installing, make sure 'gam' is reachable on your PATH "
            "or placed at ~/bin/gam7/gam."
        )
        alert.setAlertStyle_(2)  # NSCriticalAlertStyle
        alert.addButtonWithTitle_("Open Install Guide")
        alert.addButtonWithTitle_("Quit")
        response = alert.runModal()
        if response == 1000:  # first button
            import subprocess
            subprocess.run(["open", "https://github.com/GAM-team/GAM/wiki/How-to-Install-Advanced-GAM"])
    except Exception:
        print("ERROR: GAM not found. Install GAMADV-XTD3 and ensure 'gam' is on your PATH.")
    sys.exit(1)


def start_server():
    config = uvicorn.Config(fastapi_app, host="127.0.0.1", port=PORT, log_level="error")
    uvicorn.Server(config).run()


def wait_for_server(timeout=10):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            urllib.request.urlopen(URL, timeout=1)
            return True
        except Exception:
            time.sleep(0.2)
    return False


if __name__ == "__main__":
    set_app_name()

    # Check GAM before doing anything else
    if GAM is None:
        gam_alert()

    # Authenticate via Touch ID / macOS password
    if not authenticate():
        sys.exit(0)

    t = threading.Thread(target=start_server, daemon=True)
    t.start()
    wait_for_server()

    window = webview.create_window(
        "GAM Admin — Aircall IT",
        URL,
        width=1100,
        height=760,
        min_size=(800, 600),
    )
    webview.start()
