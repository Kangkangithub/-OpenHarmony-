<div align="center">

# 基于 OpenHarmony 的产品能效标签与缺陷检测系统

一个面向家电工厂场景的端侧 AI 质检项目，聚焦能效标签的
**等级识别、缺陷检测、OCR 校验与位置分析**

`OpenHarmony` `ArkUI` `MindSpore Lite` `YOLO` `OCR`

</div>

## 项目简介
本项目基于 **OpenHarmony** 实现产品能效标签的智能识别与缺陷检测，结合 **ArkUI + MindSpore Lite + YOLO + CoreVision OCR**，完成从图像采集、端侧推理到结果展示的完整闭环。

系统重点解决以下问题：
- 能效标签等级是否识别正确
- 标签是否存在破损、污渍、褶皱等缺陷
- 标签位置是否贴附异常
- 标签中的型号与等级信息是否与预设标准一致

## 功能亮点
| 功能模块 | 说明 |
| --- | --- |
| 能效等级识别 | 基于 YOLO 分类模型识别 1-5 级能效标签 |
| 缺陷检测 | 检测破损、污渍、褶皱、位置异常等状态 |
| OCR 校验 | 调用 CoreVision Kit 提取型号与文字等级 |
| 位置分析 | 结合目标检测能力分析标签相对产品主体的偏移 |
| 实时检测 | 接入相机预览流，进行端侧实时推理与结果展示 |

## 技术栈
- **系统与界面**：OpenHarmony、ArkUI、ArkTS
- **端侧推理**：MindSpore Lite Kit
- **视觉能力**：CoreVision Kit、Camera Kit、Image Kit
- **模型方案**：YOLO11 分类模型
- **训练环境**：Python、Ultralytics、Colab

## 系统流程
```text
相机采集画面
   ↓
转换为 PixelMap
   ↓
MindSpore Lite 加载 best.ms 执行分类推理
   ↓
OCR 提取型号与等级文字
   ↓
目标检测分析标签位置
   ↓
融合结果并输出最终检测结论
```

## 项目结构
```text
entry/src/main/ets/
├── entryability/      # 应用入口
├── model/             # AI 模型加载、推理、结果解析
├── services/          # 相机服务封装
└── pages/             # 首页、检测页、历史页、说明页

YOLO_DataTraining/
├── dataset_split.py   # 数据集划分脚本
├── To_onnx.py         # ONNX 导出脚本
└── yolo_cls_25cls/    # 训练参数、结果、权重文件
```

## 模型与数据集
- **当前模型**：25 分类模型
- **类别设计**：`能效等级 + 标签状态`
- **示例类别**：`level1_normal`、`level2_damage`、`level3_stain`、`level4_position_error`、`level5_wrinkle`
- **总类别数**：25 类
- **总样本数**：1425
- **数据划分**：7 : 2 : 1
- **数据位置**：`YOLO_DataTraining/content/drive/MyDrive/dataset0318`

模型部署链路：

```text
best.pt
  ↓
best.onnx
  ↓
best.ms
  ↓
OpenHarmony 端侧加载运行
```

## 项目亮点
- 打通了 **训练 - 导出 - 转换 - 部署 - 运行** 的完整端侧 AI 流程
- 融合 **分类模型 + OCR + 位置分析** 三类能力
- 基于 OpenHarmony 原生能力落地工业质检场景
- 具备升级为 **分类模型 + 检测模型** 双模型架构的良好基础

## 后续规划
- 增加专用检测模型，专门处理 `position_error`
- 将位置偏移判断从分类任务中解耦
- 增加历史记录持久化与结果导出
- 支持更多产品型号和标准规则配置

## 适用场景
- 家电生产线能效标签检测
- 工业视觉端侧部署示范
- OpenHarmony + AI 项目竞赛展示

## 文档说明
- GitHub 首页精简版：`README.md`
- 项目完整技术文档：[README_FULL.md](./README_FULL.md)
