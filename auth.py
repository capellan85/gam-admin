import sys
import threading
from LocalAuthentication import LAContext, LAPolicyDeviceOwnerAuthentication

REASON = "Authenticate to open GAM Admin"


def authenticate() -> bool:
    """
    Prompt Touch ID / macOS login password.
    Returns True if the user authenticated successfully, False otherwise.
    Blocks until the prompt is dismissed.
    """
    ctx = LAContext.new()
    can_eval, _ = ctx.canEvaluatePolicy_error_(LAPolicyDeviceOwnerAuthentication, None)
    if not can_eval:
        # No auth available — fail open so the app doesn't become unusable
        return True

    result_holder = [None]
    event = threading.Event()

    def handler(success, error):
        result_holder[0] = success
        event.set()

    ctx.evaluatePolicy_localizedReason_reply_(
        LAPolicyDeviceOwnerAuthentication,
        REASON,
        handler,
    )

    event.wait(timeout=60)
    return bool(result_holder[0])
