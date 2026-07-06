import subprocess
import shlex
import csv
import io
import os
import pwd
import shutil
from pathlib import Path
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import List, Optional

BASE_DIR = Path(__file__).parent

VERSION = "Beta 1.5"

def _find_gam() -> str | None:
    try:
        real_home = Path(pwd.getpwuid(os.getuid()).pw_dir)
    except Exception:
        real_home = Path.home()

    candidates = [
        real_home / "bin/gam7/gam",
        real_home / "bin/gam/gam",
        real_home / "GAMadv-XTD3/gam",
        real_home / "GAMadv-xtd3/gam",
        real_home / "GAMADV-XTD3/gam",
        Path("/usr/local/bin/gam"),
        Path("/opt/homebrew/bin/gam"),
    ]
    for p in candidates:
        if p.is_file() and os.access(p, os.X_OK):
            return str(p)

    shell_env = {"HOME": str(real_home), "TERM": "dumb", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"}
    for shell, flag in [("zsh", "-l"), ("bash", "-l"), ("zsh", "-i"), ("bash", "-i")]:
        try:
            result = subprocess.run(
                [shell, flag, "-c", "which gam 2>/dev/null || command -v gam 2>/dev/null"],
                capture_output=True, text=True, timeout=8, env=shell_env
            )
            gam = (result.stdout.strip().splitlines() or [""])[0]
            if gam and not gam.startswith("gam:") and Path(gam).is_file():
                return gam
        except Exception:
            pass

    return shutil.which("gam")

GAM = _find_gam()

app = FastAPI()


def run_gam(*args: str, timeout: int = 60) -> dict:
    if GAM is None:
        return {"ok": False, "output": "GAM is not installed or not found. See the health check for details."}
    cmd = [GAM] + list(args)
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        output = result.stdout + result.stderr
        return {"ok": result.returncode == 0, "output": output.strip()}
    except subprocess.TimeoutExpired:
        return {"ok": False, "output": "Command timed out."}
    except Exception as e:
        return {"ok": False, "output": str(e)}


# ── Models ────────────────────────────────────────────────────────────────────

class EmailRequest(BaseModel):
    email: str

class TransferDriveRequest(BaseModel):
    from_email: str
    to_email: str

class TransferCalendarRequest(BaseModel):
    from_email: str
    calendar_id: str
    to_email: str

class OOORequest(BaseModel):
    email: str
    subject: str
    message: str
    start_date: str
    end_date: str

class OOOOffRequest(BaseModel):
    email: str

class FileSearchRequest(BaseModel):
    owner_email: str
    query: str

class FileTransferRequest(BaseModel):
    from_email: str
    to_email: str
    file_ids: List[str]

class SuspendRequest(BaseModel):
    email: str
    suspend: bool

class ResetPasswordRequest(BaseModel):
    email: str

class GroupMemberRequest(BaseModel):
    group_email: str
    user_email: str

class UserGroupsRequest(BaseModel):
    email: str

class DelegateRequest(BaseModel):
    owner_email: str
    delegate_email: str

class UpdateUserRequest(BaseModel):
    email: str
    firstname: Optional[str] = None
    lastname: Optional[str] = None
    title: Optional[str] = None
    department: Optional[str] = None

class SharedDrivesRequest(BaseModel):
    email: str

class OffboardingRequest(BaseModel):
    from_email: str
    to_email: str
    ooo_subject: str
    ooo_message: str
    ooo_start: str
    ooo_end: str

class CustomCommandRequest(BaseModel):
    command: str


# ── Health / Version ──────────────────────────────────────────────────────────

@app.get("/api/version")
def app_version():
    return {"version": VERSION}

@app.get("/api/health")
def health():
    if GAM is None:
        return {"ok": False, "gam_found": False,
                "error": "GAM not found. Install GAMADV-XTD3 and make sure it is on your PATH."}
    try:
        r = subprocess.run([GAM, "version"], capture_output=True, text=True, timeout=10)
        gam_ver = (r.stdout + r.stderr).strip().splitlines()[0] if r.stdout or r.stderr else "unknown"
        return {"ok": True, "gam_found": True, "gam_path": GAM, "version": gam_ver}
    except Exception as e:
        return {"ok": False, "gam_found": True, "gam_path": GAM,
                "error": f"GAM found but failed to run: {e}"}


# ── Drive ─────────────────────────────────────────────────────────────────────

@app.post("/api/transfer-drive")
def transfer_drive(req: TransferDriveRequest):
    return run_gam("user", req.from_email, "transfer", "drive", req.to_email,
                   "retainrole", "writer")

@app.post("/api/search-files")
def search_files(req: FileSearchRequest):
    result = subprocess.run(
        [GAM, "user", req.owner_email, "print", "filelist",
         "query", f"name contains '{req.query}'"],
        capture_output=True, text=True, timeout=60
    )
    raw = result.stdout.strip()
    if not raw:
        return {"ok": False, "files": [], "output": (result.stderr or "No results.").strip()}
    try:
        reader = csv.DictReader(io.StringIO(raw))
        files = []
        for row in reader:
            link = row.get("webViewLink", "")
            file_id = ""
            for part in link.split("/"):
                if len(part) > 20 and part not in ("document", "spreadsheets", "presentation", "file"):
                    file_id = part
                    break
            name = row.get("name") or "(untitled)"
            mime = row.get("mimeType") or ""
            modified = (row.get("modifiedTime") or "")[:10]
            if name != "(untitled)":
                files.append({"id": file_id or name, "name": name, "mimeType": mime, "modified": modified})
        return {"ok": True, "files": files, "output": f"{len(files)} file(s) found"}
    except Exception as e:
        return {"ok": False, "files": [], "output": str(e)}

@app.post("/api/transfer-files")
def transfer_files(req: FileTransferRequest):
    results = []
    for file_id in req.file_ids:
        r = run_gam("user", req.from_email, "transfer", "ownership", file_id, req.to_email)
        results.append({"id": file_id, "ok": r["ok"], "output": r["output"]})
    all_ok = all(r["ok"] for r in results)
    summary = "\n".join(f"{'✓' if r['ok'] else '✗'} {r['id']}: {r['output']}" for r in results)
    return {"ok": all_ok, "output": summary}


# ── Calendar ──────────────────────────────────────────────────────────────────

@app.post("/api/transfer-calendar")
def transfer_calendar(req: TransferCalendarRequest):
    return run_gam("user", req.from_email, "add", "calendaracl",
                   req.calendar_id, "role", "owner", "user", req.to_email)


# ── Messaging ─────────────────────────────────────────────────────────────────

@app.post("/api/ooo-on")
def ooo_on(req: OOORequest):
    return run_gam("user", req.email, "vacation", "on",
                   "subject", req.subject,
                   "message", req.message,
                   "startdate", req.start_date,
                   "enddate", req.end_date)

@app.post("/api/ooo-off")
def ooo_off(req: OOOOffRequest):
    return run_gam("user", req.email, "vacation", "off")

@app.post("/api/delegate-mailbox")
def delegate_mailbox(req: DelegateRequest):
    return run_gam("user", req.owner_email, "add", "delegate", req.delegate_email)


# ── Users ─────────────────────────────────────────────────────────────────────

@app.post("/api/user-info")
def user_info(req: EmailRequest):
    return run_gam("info", "user", req.email)

@app.post("/api/suspend-user")
def suspend_user(req: SuspendRequest):
    action = "true" if req.suspend else "false"
    return run_gam("update", "user", req.email, "suspended", action)

@app.post("/api/reset-password")
def reset_password(req: ResetPasswordRequest):
    return run_gam("update", "user", req.email, "password", "random",
                   "changepassword", "on")

@app.post("/api/update-user")
def update_user(req: UpdateUserRequest):
    args = ["update", "user", req.email]
    if req.firstname: args += ["firstname", req.firstname]
    if req.lastname:  args += ["lastname",  req.lastname]
    if req.title:     args += ["title",     req.title]
    if req.department: args += ["department", req.department]
    if len(args) == 3:
        return {"ok": False, "output": "No fields to update."}
    return run_gam(*args)


# ── Groups ────────────────────────────────────────────────────────────────────

@app.post("/api/group-add")
def group_add(req: GroupMemberRequest):
    return run_gam("update", "group", req.group_email, "add", "member", req.user_email)

@app.post("/api/group-remove")
def group_remove(req: GroupMemberRequest):
    return run_gam("update", "group", req.group_email, "remove", "member", req.user_email)

@app.post("/api/user-groups")
def user_groups(req: UserGroupsRequest):
    result = subprocess.run(
        [GAM, "user", req.email, "print", "groups"],
        capture_output=True, text=True, timeout=60
    )
    raw = result.stdout.strip()
    if not raw:
        return {"ok": False, "groups": [], "output": (result.stderr or "No groups found.").strip()}
    try:
        reader = csv.DictReader(io.StringIO(raw))
        groups = []
        for row in reader:
            # GAM outputs "Group" (capital G); fall back to lowercase variants
            row_lower = {k.lower(): v for k, v in row.items()}
            email = row_lower.get("group") or row_lower.get("email") or ""
            name  = row_lower.get("name") or email
            if email:
                groups.append({"email": email, "name": name})
        return {"ok": True, "groups": groups, "output": f"{len(groups)} group(s) found"}
    except Exception as e:
        return {"ok": False, "groups": [], "output": str(e)}

@app.post("/api/remove-all-groups")
def remove_all_groups(req: EmailRequest):
    # First get all groups
    list_result = subprocess.run(
        [GAM, "user", req.email, "print", "groups"],
        capture_output=True, text=True, timeout=60
    )
    raw = list_result.stdout.strip()
    if not raw:
        return {"ok": True, "output": "User is not a member of any groups."}
    try:
        reader = csv.DictReader(io.StringIO(raw))
        group_emails = [{k.lower(): v for k, v in row.items()} for row in reader]
        group_emails = [r.get("group") or r.get("email") for r in group_emails]
        group_emails = [g for g in group_emails if g]
    except Exception as e:
        return {"ok": False, "output": str(e)}

    results = []
    for group in group_emails:
        r = run_gam("update", "group", group, "remove", "member", req.email)
        results.append(f"{'✓' if r['ok'] else '✗'} {group}")

    return {"ok": True, "output": f"Removed from {len(results)} group(s):\n" + "\n".join(results)}


# ── Shared Drives ─────────────────────────────────────────────────────────────

@app.post("/api/shared-drives")
def shared_drives(req: SharedDrivesRequest):
    result = subprocess.run(
        [GAM, "user", req.email, "print", "shareddrives"],
        capture_output=True, text=True, timeout=60
    )
    raw = result.stdout.strip()
    if not raw:
        return {"ok": False, "drives": [], "output": (result.stderr or "No shared drives found.").strip()}
    try:
        reader = csv.DictReader(io.StringIO(raw))
        drives = []
        for row in reader:
            drives.append({
                "id":   row.get("id", ""),
                "name": row.get("name", "(unnamed)"),
            })
        return {"ok": True, "drives": drives, "output": f"{len(drives)} shared drive(s) found"}
    except Exception as e:
        return {"ok": False, "drives": [], "output": str(e)}


# ── Offboarding Workflow ──────────────────────────────────────────────────────

@app.post("/api/offboarding")
def offboarding(req: OffboardingRequest):
    steps = []

    def step(label, *args):
        r = run_gam(*args, timeout=120)
        steps.append({"label": label, "ok": r["ok"], "output": r["output"]})
        return r["ok"]

    step("Suspend account",
         "update", "user", req.from_email, "suspended", "true")

    step("Transfer Drive",
         "user", req.from_email, "transfer", "drive", req.to_email, "retainrole", "writer")

    step("Transfer primary calendar",
         "user", req.from_email, "add", "calendaracl",
         req.from_email, "role", "owner", "user", req.to_email)

    step("Set Out-of-Office",
         "user", req.from_email, "vacation", "on",
         "subject", req.ooo_subject,
         "message", req.ooo_message,
         "startdate", req.ooo_start,
         "enddate", req.ooo_end)

    all_ok = all(s["ok"] for s in steps)
    summary = "\n".join(f"{'✓' if s['ok'] else '✗'} {s['label']}" for s in steps)
    return {"ok": all_ok, "steps": steps, "output": summary}


# ── Custom ────────────────────────────────────────────────────────────────────

@app.post("/api/custom")
def custom_command(req: CustomCommandRequest):
    blocked = ["delete", "remove", "suspend", "purge", "--force"]
    lower = req.command.lower()
    for word in blocked:
        if word in lower:
            return {"ok": False, "output": f"Blocked: '{word}' requires confirmation. Run from terminal directly."}
    args = shlex.split(req.command)
    return run_gam(*args)


app.mount("/", StaticFiles(directory=str(BASE_DIR / "static"), html=True), name="static")
