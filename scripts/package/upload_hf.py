#!/usr/bin/env python3
"""Upload a ROM zip to Hugging Face (dataset repo, modern huggingface_hub API).

P1: replaces removed batch_bucket_files/get_bucket_paths_info with
upload_file + file_download/history verification.
"""

import argparse
import hashlib
import os
import sys

from huggingface_hub import HfApi
from huggingface_hub.utils import HfHubHTTPError


def sha256_of(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(4 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Upload a ROM zip to Hugging Face.")
    parser.add_argument("local_path", help="Local path of the .zip file to upload")
    parser.add_argument("remote_path", help="Destination path inside the repo")
    parser.add_argument(
        "--repo",
        default=os.environ.get("HF_REPO", os.environ.get("HF_BUCKET")),
        help="Repo id (owner/name). Defaults to $HF_REPO / $HF_BUCKET / $HF_USER/LumiROM",
    )
    parser.add_argument(
        "--repo-type",
        default=os.environ.get("HF_REPO_TYPE", "dataset"),
        help="Repo type (default: dataset)",
    )
    parser.add_argument(
        "--token",
        default=os.environ.get("HF_TOKEN"),
        help="Hugging Face access token. Defaults to $HF_TOKEN",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()

    repo = args.repo
    if not repo:
        hf_user = os.environ.get("HF_USER", "")
        if not hf_user:
            print("ERROR: no --repo and HF_USER is not set.", file=sys.stderr)
            return 1
        repo = f"{hf_user}/LumiROM"

    if not os.path.isfile(args.local_path):
        print(f"ERROR: File not found: {args.local_path}", file=sys.stderr)
        return 1
    if not args.token:
        print("ERROR: HF_TOKEN is not set.", file=sys.stderr)
        return 1

    local_sha = sha256_of(args.local_path)
    size = os.path.getsize(args.local_path)
    print(f"Local: {args.local_path} ({size} bytes, sha256={local_sha})")
    print(f"Uploading -> hf://{repo}/{args.remote_path} (type={args.repo_type})")

    api = HfApi(token=args.token)
    try:
        url = api.upload_file(
            path_or_fileobj=args.local_path,
            path_in_repo=args.remote_path,
            repo_id=repo,
            repo_type=args.repo_type,
        )
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        return 130
    except HfHubHTTPError as exc:
        print(f"ERROR: upload failed (HTTP): {exc}", file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"ERROR: upload failed: {exc}", file=sys.stderr)
        return 1

    print(f"OK: uploaded {url}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
