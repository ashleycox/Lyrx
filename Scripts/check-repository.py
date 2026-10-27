#!/usr/bin/env python3
"""Reject private signing data and user-specific state in tracked or staged files."""
import re
import subprocess
import sys
from pathlib import Path

staged = "--staged" in sys.argv
paths = subprocess.check_output(["git", "ls-files", "-z"]).decode().split("\0")
problems = []
for name in filter(None, paths):
    path = Path(name)
    if "xcuserdata" in path.parts or name.endswith((".p12", ".p8", ".cer", ".mobileprovision", ".provisionprofile", ".xcuserstate")) or name == "Configuration/Local.xcconfig":
        problems.append(f"Private or user-specific file: {name}")
        continue
    if path.suffix not in {".pbxproj", ".xcconfig", ".plist", ".entitlements", ".swift", ".yml"}:
        continue
    if staged:
        contents = subprocess.check_output(["git", "show", f":{name}"]).decode(errors="replace")
    elif path.exists():
        contents = path.read_text(errors="replace")
    else:
        continue
    if re.search(r"DEVELOPMENT_TEAM\s*=\s*\"?[A-Z0-9]{10}\b", contents):
        problems.append(f"Personal signing team: {name}")
    if re.search(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----", contents):
        problems.append(f"Private key: {name}")
    identifiers = re.findall(r"PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);", contents)
    if path.suffix == ".pbxproj" and any(value.strip().strip('"') not in {"$(LYRX_BUNDLE_IDENTIFIER)", "org.lyrx.app.UITests"} for value in identifiers):
        problems.append(f"Bundle identifier must use local configuration: {name}")
if problems:
    print("\n".join(problems), file=sys.stderr)
    sys.exit(1)
print("Repository privacy checks passed.")
