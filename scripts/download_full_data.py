#!/usr/bin/env python3
"""Download the full Netflix Movies and TV Shows dataset into data/raw_full/ and verify its SHA-256.

Kaggle  : https://www.kaggle.com/datasets/shivamb/netflix-shows  (netflix_titles.csv, Shivam Bansal; snapshot to 2021-09-25)
Mirror  : https://huggingface.co/datasets/hugginglearners/netflix-shows  (same 8,807 rows; final newline dropped, 3,399,670 B)
Fallback: https://huggingface.co/datasets/harshi321/netflix-movies_shows (3,399,671 B, the same size as the Kaggle file)
Licence : CC0: Public Domain (Kaggle listing; the Hugging Face mirror is tagged cc0-1.0)
"""
import hashlib, pathlib, sys, urllib.request

SOURCES = [  # (url, bytes, sha256)
    ("https://huggingface.co/datasets/hugginglearners/netflix-shows/resolve/main/netflix_titles.csv", 3399670,
     "b5e2528aaac6a9a1544f68fb1ad004f46fabbf8bc2644d96f7364ca8b66ce959"),
    ("https://huggingface.co/datasets/harshi321/netflix-movies_shows/resolve/main/netflix_titles.csv", 3399671,
     "df1f4ad2027a5a14c3a33932ef0d4054565ff88adf92b7f263601b70fdc6f3f3"),
]


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


out = pathlib.Path(__file__).resolve().parents[1] / "data" / "raw_full"
out.mkdir(parents=True, exist_ok=True)
p = out / "netflix_titles.csv"
good = {d for _, _, d in SOURCES}
if p.exists() and sha(p) in good:
    print(f"{p.name} already present and verified ({p.stat().st_size:,} bytes)")
    sys.exit(0)
for url, size, digest in SOURCES:
    print("downloading", url, flush=True)
    try:
        urllib.request.urlretrieve(url, p)
    except Exception as e:  # try the next mirror
        print("  failed:", e)
        continue
    if sha(p) == digest:
        print(f"{p.name} {p.stat().st_size:,} bytes  OK (SHA-256 verified)")
        sys.exit(0)
    print("  checksum mismatch, trying next mirror")
print("could not download a verified copy")
sys.exit(1)
