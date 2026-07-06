import os
import signal
import subprocess
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


def kill_stale_server(port: int) -> None:
    """Kill any process already listening on our port (stale previous launch)."""
    try:
        result = subprocess.run(
            ["lsof", "-t", "-i", f":{port}", "-s", "TCP:LISTEN"],
            capture_output=True, text=True
        )
        for pid_str in result.stdout.strip().splitlines():
            try:
                pid = int(pid_str.strip())
                if pid != os.getpid():
                    os.kill(pid, signal.SIGTERM)
            except Exception:
                pass
        if result.stdout.strip():
            time.sleep(0.4)
    except Exception:
        pass


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
    kill_stale_server(PORT)

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
