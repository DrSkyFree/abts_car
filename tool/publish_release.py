"""创建 GitHub Release 并上传 APK（车机版 v1.3.0）

用法：
    python tool/publish_release.py <tag> <title> <notes_file> <apk_dir>

依赖：requests 或 urllib（标准库即可），需要一个具备 repo 权限的 PAT。
PAT 从 git credential 中读取，不落盘到仓库。
"""
import base64
import json
import mimetypes
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

REPO = "DrSkyFree/abts_car"
API = f"https://api.github.com/repos/{REPO}"
UPLOAD = f"https://uploads.github.com/repos/{REPO}/releases"


def get_token() -> str:
    """从 git credential helper 读取已缓存的 PAT"""
    proc = subprocess.run(
        ["git", "credential", "fill"],
        input="protocol=https\nhost=github.com\n\n",
        capture_output=True,
        text=True,
    )
    for line in proc.stdout.splitlines():
        if line.startswith("password="):
            return line[len("password="):].strip()
    raise SystemExit("未找到 GitHub 凭据，请先执行一次 git push 以缓存凭据")


def api(method: str, url: str, token: str, data=None, headers=None, raw=False):
    hdrs = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "abts-car-release",
    }
    if headers:
        hdrs.update(headers)
    body = None
    if data is not None:
        body = json.dumps(data).encode()
        hdrs["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=body, headers=hdrs, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            content = resp.read()
            return content if raw else json.loads(content or b"{}")
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:600]
        raise SystemExit(f"{method} {url} -> HTTP {e.code}\n{detail}")


def upload_asset(token: str, release_id: int, path: str) -> None:
    name = os.path.basename(path)
    size = os.path.getsize(path)
    ctype = mimetypes.guess_type(name)[0] or "application/vnd.android.package-archive"
    url = f"{UPLOAD}/{release_id}/assets?name={name}"
    print(f"  上传 {name} ({size/1048576:.1f} MB)")
    with open(path, "rb") as f:
        req = urllib.request.Request(
            url,
            data=f,
            method="POST",
            headers={
                "Authorization": f"Bearer {token}",
                "Accept": "application/vnd.github+json",
                "Content-Type": ctype,
                "Content-Length": str(size),
                "User-Agent": "abts-car-release",
            },
        )
        with urllib.request.urlopen(req, timeout=1800) as resp:
            result = json.loads(resp.read() or b"{}")
    print(f"    OK -> {result.get('browser_download_url', '?')}")


def main() -> None:
    if len(sys.argv) < 5:
        raise SystemExit(__doc__)
    tag, title, notes_file, apk_dir = sys.argv[1:5]

    token = get_token()
    with open(notes_file, encoding="utf-8") as f:
        notes = f.read()

    apks = sorted(
        os.path.join(apk_dir, n)
        for n in os.listdir(apk_dir)
        if n.endswith(".apk")
    )
    if not apks:
        raise SystemExit(f"{apk_dir} 里没有 APK")
    print(f"待发布 {len(apks)} 个 APK，tag={tag}")

    # 1. 创建 tag + Release
    payload = {
        "tag_name": tag,
        "name": title,
        "body": notes,
        "draft": False,
        "prerelease": False,
        "make_latest": "true",
    }
    release = api("POST", f"{API}/releases", token, payload)
    release_id = release["id"]
    print(f"Release 已创建: id={release_id} url={release['html_url']}")

    # 2. 逐个上传
    for apk in apks:
        upload_asset(token, release_id, apk)

    # 3. 回读确认
    final = api("GET", f"{API}/releases/{release_id}", token)
    print("\n发布完成：")
    print(f"  {final['html_url']}")
    for a in final.get("assets", []):
        print(f"  - {a['name']}  {a['size']/1048576:.1f} MB  {a['browser_download_url']}")


if __name__ == "__main__":
    main()
