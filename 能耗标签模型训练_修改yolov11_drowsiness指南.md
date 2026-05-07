# 如何把 yolov11_drowsiness.ipynb 改成中国能耗标签识别训练（dataset0318）

目标：在 **不下载新数据** 的前提下，把原本“Drowsiness Detection（二分类）”的 Ultralytics YOLO 分类训练流程，改为能耗标签数据集 `/content/drive/MyDrive/dataset0318` 的训练流程，并满足：

- 能耗等级识别：Level 1–5（5 分类）
- 缺陷检测：damage / stain / wrinkle / normal（4 分类）
- 位置检测：position_error（位置偏差）
- 推理时输出：能耗等级 + 缺陷/位置；并提供一个“识别到的标签文字信息 vs 预设产品型号”比对接口

你的最新数据结构已经是“单层类别目录”，一共有 `5 个能耗等级 × 5 个缺陷/位置 = 25 类`（例如 `level1_damage`、`level2_normal`）。这正好符合 Ultralytics 分类训练的目录要求，因此建议落地方案（推荐）是：**单模型 25 分类**。

训练完成后，在推理阶段把预测到的 `class_name`（例如 `level2_damage`）按下划线拆开，即可得到：

- `energy_level = 2`
- `defect = damage`
- `position_ok = (defect != "position_error")`

这样不需要额外复制/重排数据，训练、评估、部署也更简单。

---

## 1. 先确认原始数据结构

你的云端硬盘数据结构（你最新提供的）：

```text
/content/drive/MyDrive/dataset0318/
  train/
    level1_damage/
    level1_normal/
    level1_position_error/
    level1_stain/
    level1_wrinkle/
    ...
    level5_damage/
    level5_normal/
    level5_position_error/
    level5_stain/
    level5_wrinkle/
  val/
    level1_damage/...
  test/
    level1_damage/...
```

一共 25 个类别文件夹，每个文件夹 20–50 张图。文件夹名大小写不敏感，但建议统一使用 `level{1..5}_{defect}` 的小写命名（例如 `level3_damage`、`level4_normal`）。

---

## 2. 在 yolov11_drowsiness.ipynb 里需要改哪些地方（按单元格）

下面用“原笔记本的 cell 编号”描述改法。你可以在 Notebook 左侧/顶部看到 cell 的顺序；也可以在 `.ipynb` 里按关键字搜索。

### 2.1 保留：挂载云端硬盘（cell 7）

原始 cell 7：

```python
from google.colab import drive
drive.mount('/content/drive')
```

保留不动（这是访问 `/content/drive/MyDrive/...` 的前提）。

---

### 2.2 替换：路径配置（cell 9）

原始 cell 9 里 `DATASET_PATH = os.path.join(HOME, "dataset")` 是给下载/整理疲劳数据集用的。你现在的数据已经是 `train/val/test + 25 个类别文件夹` 的结构，因此只需要把 `DATASET_PATH` 指向你的云端硬盘路径即可。

用下面代码**替换整个 cell 9**：

```python
import os

DOWNLOAD_PATH = os.path.join(HOME, "downloads")

RAW_DATASET_PATH = "/content/drive/MyDrive/dataset0318"
DATASET_PATH = RAW_DATASET_PATH

VISUALIZATION_PATH = os.path.join(HOME, "visualizations")

os.makedirs(DOWNLOAD_PATH, exist_ok=True)
os.makedirs(VISUALIZATION_PATH, exist_ok=True)

print("RAW_DATASET_PATH:", RAW_DATASET_PATH)
print("DATASET_PATH:", DATASET_PATH)
print("VISUALIZATION_PATH:", VISUALIZATION_PATH)
```

说明：

- `RAW_DATASET_PATH` 指向你已有数据，不再使用 `DATASET_PATH=/workspace/dataset`。
- 你的 `DATASET_PATH` 直接等于 `RAW_DATASET_PATH`，因为类别目录已是扁平结构（25 类）。

---

### 2.3 删除/跳过：Kaggle 下载（cell 11）

原始 cell 11 使用 `kagglehub.dataset_download()` 下载疲劳数据集。你现在**不需要下载步骤**，因此：

- 直接删除该 cell 或者在开头加一行 `raise SystemExit("Skip kaggle download")` 强行跳过。
- 更推荐：整段删掉，避免误执行。

---

### 2.4 替换：数据整理（cell 15）

原始 cell 15 是把 Kaggle 疲劳数据集搬运/拆分为 train/val/test，并创建 `Drowsy/Non Drowsy` 目录。

你现在的 dataset0318 已经是标准 Ultralytics 分类结构：`train/val/test` + `train/<class_name>/*.jpg`（25 类），因此 **不需要任何数据整理/复制/重排**。建议做法：

- 删除 cell 15（最简单）
- 或者把 cell 15 替换为“数据结构自检”，确保 25 个类别都在，并统计每类样本数量（推荐）

用下面代码**替换整个 cell 15**：

```python
import os
from collections import Counter

IMG_EXTS = (".jpg", ".jpeg", ".png", ".bmp", ".webp")

def _list_classes(split_dir):
    return sorted([d for d in os.listdir(split_dir) if os.path.isdir(os.path.join(split_dir, d))])

def _count_images_in_class_dir(class_dir):
    n = 0
    for fn in os.listdir(class_dir):
        if fn.lower().endswith(IMG_EXTS):
            n += 1
    return n

for split in ["train", "val", "test"]:
    split_dir = os.path.join(DATASET_PATH, split)
    classes = _list_classes(split_dir)
    print(split, "class_count=", len(classes))
    print("  sample classes:", classes[:10])
    counts = {c: _count_images_in_class_dir(os.path.join(split_dir, c)) for c in classes}
    print("  total images:", sum(counts.values()))
    print("  min/max per class:", (min(counts.values()) if counts else 0), (max(counts.values()) if counts else 0))
```

---

### 2.5 修改：可视化与统计相关单元（cell 20 / 22 / 25 等）

这些 cell 大多是 `os.walk(DATASET_PATH)` 或 `ClassificationDataset(root=...)` 做图像预览与增强可视化。

修改原则：

- 你的训练数据就是 `DATASET_PATH=/content/drive/MyDrive/dataset0318`，因此可视化/统计全部直接使用 `DATASET_PATH` 即可。

例如原始 cell 20：

```python
for root, dirs, files in os.walk(DATASET_PATH):
    ...
```

不需要替换变量名；如果你想只看某一个 split，可以改成：

```python
for root, dirs, files in os.walk(os.path.join(DATASET_PATH, "train")):
    ...
```

---

### 2.6 修改：训练单元（cell 31）——训练单模型 25 分类

原始 cell 31 训练一个二分类模型：

```python
results = model.train(data=DATASET_PATH, ...)
```

现在把 `data` 指向你的 dataset0318 根目录即可（Ultralytics 会自动读取 `train/val/test` 及其 25 个类别文件夹），训练得到一个 `best.pt`：

```python
from ultralytics import YOLO

BASE_WEIGHTS = "yolo11x-cls"

model = YOLO(BASE_WEIGHTS)
results = model.train(
    data=DATASET_PATH,
    epochs=300,
    imgsz=224,
    batch=-1,
    patience=20,
    project="energy_label_training_25cls",
    name="yolo_cls_25cls",
    save=True,
    device=DEVICE,
    cache=True,
    plots=True,
    exist_ok=True
)
```

---

### 2.7 修改：测试集评估（cell 42）——评估 25 分类模型

原始 cell 42 只评估一个模型，并写一个 test_config.yaml。

你可以继续用同样思路：写一个 YAML，把 `val` 指向 `test` 目录，然后对 test 集跑一次 `val()`。

用下面代码**替换整个 cell 42**：

```python
from ultralytics import YOLO
import yaml
import os

def _best_pt(run_dir):
    p = os.path.join(run_dir, "weights", "best.pt")
    if not os.path.exists(p):
        raise FileNotFoundError(f"best.pt not found: {p}")
    return p

def _make_test_yaml(dataset_root, yaml_path):
    train_dir = os.path.join(dataset_root, "train")
    test_dir = os.path.join(dataset_root, "test")
    names = sorted([d for d in os.listdir(train_dir) if os.path.isdir(os.path.join(train_dir, d))])
    data_yaml = {"train": train_dir, "val": test_dir, "names": names}
    with open(yaml_path, "w", encoding="utf-8") as f:
        yaml.safe_dump(data_yaml, f, allow_unicode=True, sort_keys=False)
    return yaml_path

best_model_path = _best_pt(results.save_dir)
model = YOLO(best_model_path)

test_yaml = _make_test_yaml(DATASET_PATH, os.path.join(HOME, "energy_label_25cls_test.yaml"))

print("Evaluating 25-class model on test set...")
test_results = model.val(
    data=test_yaml,
    project="energy_label_evaluation_25cls",
    name="test_set_eval",
    exist_ok=True,
    split="val"
)
```

---

### 2.8 新增：推理输出 + 位置判定 + OCR 与产品型号比对

你要的最终输出不是单纯分类结果，还需要：

- 位置检测：若预测类别名形如 `levelX_position_error`，则判定“位置不合规”
- 识别标签数据信息并与预设产品型号比对：需要 OCR（文字识别）

做法：在 notebook 后面新增一个 code cell（或复用最后的空 cell），加入下面函数（可直接复制）：

```python
import os
from pathlib import Path

IMG_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

def _maybe_ocr_text(image_path):
    try:
        import easyocr
        reader = easyocr.Reader(["ch_sim", "en"], gpu=False)
        res = reader.readtext(str(image_path), detail=0)
        return "\n".join(res)
    except Exception:
        pass

    try:
        import pytesseract
        import cv2
        img = cv2.imread(str(image_path))
        if img is None:
            return ""
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        gray = cv2.threshold(gray, 0, 255, cv2.THRESH_OTSU | cv2.THRESH_BINARY)[1]
        return pytesseract.image_to_string(gray, lang="chi_sim+eng")
    except Exception:
        return ""

def _predict_top1(yolo_model, image_path):
    pred = yolo_model.predict(source=str(image_path), verbose=False)
    if not pred:
        return None
    p = pred[0]
    probs = getattr(p, "probs", None)
    if probs is None:
        return None
    top1 = int(probs.top1)
    conf = float(probs.top1conf)
    name = yolo_model.names[top1] if isinstance(yolo_model.names, dict) else yolo_model.names[top1]
    return {"class_id": top1, "class_name": name, "conf": conf}

def compare_with_expected(ocr_text, expected):
    text = (ocr_text or "").upper()
    mismatches = []

    model_expected = expected.get("model")
    if model_expected:
        ok = model_expected.upper() in text
        if not ok:
            mismatches.append({"field": "model", "expected": model_expected, "found": None})

    return {"ok": len(mismatches) == 0, "mismatches": mismatches}

def _parse_level_defect(class_name):
    name = (class_name or "").lower().strip()
    parts = name.split("_", 1)
    if len(parts) != 2:
        return None, None

    level_part, defect = parts[0], parts[1]
    if not level_part.startswith("level"):
        return None, None

    try:
        level = int(level_part.replace("level", ""))
    except Exception:
        return None, None

    return level, defect


def predict_energy_label(image_path, model, expected_product=None):
    image_path = Path(image_path)

    cls_pred = _predict_top1(model, image_path)
    level, defect = _parse_level_defect(cls_pred["class_name"] if cls_pred else None)

    ocr_text = _maybe_ocr_text(image_path)

    out = {
        "image": str(image_path),
        "pred_25cls": cls_pred,
        "energy_level": level,
        "defect": defect,
        "position_ok": (defect != "position_error") if defect is not None else None,
        "ocr_text": ocr_text,
    }

    if expected_product is not None:
        out["compare"] = compare_with_expected(ocr_text, expected_product)

    return out


sample_dir = Path(RAW_DATASET_PATH) / "test"
sample_images = [p for p in sample_dir.rglob("*") if p.is_file() and p.suffix.lower() in IMG_EXTS]

if sample_images:
    img = sample_images[0]
    expected = {"model": "YOUR_PRODUCT_MODEL"}
    pred = predict_energy_label(img, model, expected_product=expected)
    pred
else:
    print("No test images found under:", sample_dir)
```

你需要根据真实业务把 `expected = {"model": "YOUR_PRODUCT_MODEL"}` 换成你的“预设产品型号信息”（例如从数据库/Excel/接口读入）。

---

## 3. 运行顺序（建议）

1. 安装依赖（保留原有 `%pip install ultralytics ...`）
2. 挂载 Drive（cell 7）
3. 路径配置（替换后的 cell 9）
4. 数据结构自检（替换后的 cell 15）
5. 训练 25 分类模型（替换后的 cell 31）
6. 评估 25 分类模型（替换后的 cell 42）
7. 推理与比对（新增推理 cell）

---

## 4. 关于“确保 99%+ 准确率”的现实约束与提升手段

代码改完只能保证“能训练、能评估、能推理”。是否达到 99%+，主要由数据决定。通常要做到 99%+，建议：

- 确保每类样本分布一致：拍摄角度、清晰度、背景、裁剪比例尽量统一
- 保证标签一致性：同一张图不要同时被不同人标成不同缺陷类别
- 对难例补样本：例如轻微褶皱 vs 污渍、轻微破损 vs 正常等边界样本
- 固定输入裁剪：如果图片里标签区域占比变化很大，建议先做“标签区域检测/裁剪”，再做分类（能显著提升准确率）

---

## 5. 位置检测的注意事项（非常关键）

你当前的数据集只有“分类标签（position_error/Normal）”，没有提供“标签在整机上的几何位置标注”。因此本指南里的“位置检测”属于：

- **基于外观的分类式位置检测**：模型学到“贴歪/不在规定位置”的外观特征 → 输出 `position_error`

如果你需要严格判断“是否贴在规定区域（几何约束）”，需要额外数据与任务形式：

- 检测/分割：给能效标签在整机图中的 bbox 或 mask 标注
- 或关键点：标注角点/参考点，计算相对位置是否落在规则区域

这属于不同训练任务（YOLO 检测/分割/关键点），不在当前“纯分类目录数据集”的能力范围内。
