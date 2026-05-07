import os
import shutil
import hashlib
import random
from pathlib import Path
from datetime import datetime

DATASET_ROOT = Path(r"C:\Users\Kangkang\Desktop\FWCX2026\DataTraining2\content\drive\MyDrive\dataset0318")
SPLITS = ["train", "val", "test"]
RATIO = (0.7, 0.2, 0.1)
IMG_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

SEED = 42
MAKE_BACKUP = True
DRY_RUN = False

def file_hash(path: Path, chunk_size: int = 1024 * 1024) -> str:
    h = hashlib.sha1()
    with path.open("rb") as f:
        while True:
            b = f.read(chunk_size)
            if not b:
                break
            h.update(b)
    return h.hexdigest()

def iter_images(dir_path: Path):
    if not dir_path.exists():
        return
    for p in dir_path.iterdir():
        if p.is_file() and p.suffix.lower() in IMG_EXTS:
            yield p

def ensure_dir(p: Path):
    p.mkdir(parents=True, exist_ok=True)

def unique_dst_path(dst_dir: Path, src: Path, suffix: str):
    base = src.stem
    ext = src.suffix.lower()
    name = f"{base}__{suffix}{ext}"
    dst = dst_dir / name
    k = 1
    while dst.exists():
        name = f"{base}__{suffix}__{k}{ext}"
        dst = dst_dir / name
        k += 1
    return dst

def compute_split_counts(n: int):
    if n <= 0:
        return 0, 0, 0
    n_train = int(n * RATIO[0])
    n_val = int(n * RATIO[1])
    n_test = n - n_train - n_val
    if n >= 3:
        if n_train == 0:
            n_train = 1
            n_test = n - n_train - n_val
        if n_val == 0:
            n_val = 1
            n_test = n - n_train - n_val
        if n_test == 0:
            n_test = 1
            if n_train > n_val:
                n_train -= 1
            else:
                n_val -= 1
    return n_train, n_val, n_test

def main():
    random.seed(SEED)

    for s in SPLITS:
        if not (DATASET_ROOT / s).exists():
            raise FileNotFoundError(f"Missing split folder: {DATASET_ROOT / s}")

    train_dir = DATASET_ROOT / "train"
    class_names = sorted([d.name for d in train_dir.iterdir() if d.is_dir()])
    if not class_names:
        raise RuntimeError(f"No class folders found under: {train_dir}")

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = DATASET_ROOT.parent / f"{DATASET_ROOT.name}_backup_{timestamp}"
    staging_dir = DATASET_ROOT.parent / f"{DATASET_ROOT.name}_staging_{timestamp}"

    if MAKE_BACKUP:
        if backup_dir.exists():
            raise RuntimeError(f"Backup dir already exists: {backup_dir}")
        if not DRY_RUN:
            shutil.copytree(DATASET_ROOT, backup_dir)
        print("Backup created:", str(backup_dir))

    if staging_dir.exists():
        raise RuntimeError(f"Staging dir already exists: {staging_dir}")
    if not DRY_RUN:
        ensure_dir(staging_dir)

    total_unique = 0

    for class_name in class_names:
        all_files = []
        for split in SPLITS:
            all_files.extend(list(iter_images(DATASET_ROOT / split / class_name)))

        seen = {}
        unique = []
        for p in all_files:
            h = file_hash(p)
            if h in seen:
                continue
            seen[h] = p
            unique.append((h, p))

        total_unique += len(unique)

        random.shuffle(unique)
        n = len(unique)
        n_train, n_val, n_test = compute_split_counts(n)

        targets = (
            ("train", unique[:n_train]),
            ("val", unique[n_train:n_train + n_val]),
            ("test", unique[n_train + n_val:]),
        )

        for split, items in targets:
            dst_dir = staging_dir / split / class_name
            if not DRY_RUN:
                ensure_dir(dst_dir)
            for h, src_path in items:
                dst_path = unique_dst_path(dst_dir, src_path, h[:10])
                if DRY_RUN:
                    continue
                shutil.copy2(src_path, dst_path)

        print(f"{class_name}: total={n} train={n_train} val={n_val} test={n_test}")

    print("Total unique images (all classes):", total_unique)

    if DRY_RUN:
        print("DRY_RUN=True: no file changes made.")
        return

    old_dir = DATASET_ROOT.parent / f"{DATASET_ROOT.name}_old_{timestamp}"
    shutil.move(str(DATASET_ROOT), str(old_dir))
    shutil.move(str(staging_dir), str(DATASET_ROOT))

    print("Re-split dataset saved to:", str(DATASET_ROOT))
    print("Old dataset moved to:", str(old_dir))

if __name__ == "__main__":
    main()