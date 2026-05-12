# 基于 OpenHarmony 的产品能效标签与缺陷检测系统

## 1. 项目概述
本项目面向家电工厂生产环节中的能效标签检测场景，基于 OpenHarmony 设计并实现了一套集**实时采集、端侧推理、OCR 校验、缺陷识别、位置分析、结果展示**于一体的产品能效标签与缺陷检测系统。

系统围绕“能效标签是否贴对、贴准、贴完整、贴规范”这一核心问题展开，利用 ArkUI 构建端侧交互界面，调用 OpenHarmony 原生相机能力采集图像，通过 MindSpore Lite 加载部署后的 `.ms` 模型实现能效等级与缺陷分类，并结合 CoreVision Kit 的 OCR 与目标检测能力，对标签型号、文字等级及标签位置进行多维度校验。

项目当前已经完成以下核心链路：

- 实时相机画面采集
- PixelMap 图像转换与预处理
- MindSpore Lite 模型加载与端侧推理
- OCR 型号/等级识别
- 多目标检测辅助位置偏移分析
- 检测结果实时显示
- 检测记录本地页面级归档

## 2. 项目目标与应用场景

### 2.1 项目目标
- 对家电产品上的能效标签进行自动识别与等级判断
- 对标签表面缺陷进行自动检测，包括破损、污渍、褶皱等情况
- 对标签贴附位置进行偏移分析，判断是否存在位置错误
- 对 OCR 识别出的型号与等级进行一致性校验，减少人工复核工作量
- 提供工业现场可运行的 OpenHarmony 端侧 AI 检测示范方案

### 2.2 应用场景
- 家电生产线出厂质检
- 包装贴标后质量复检
- 能效标签规范化巡检
- 工业视觉端侧部署教学与竞赛展示

## 3. 技术栈
- **操作系统**：OpenHarmony
- **界面框架**：ArkUI / ArkTS
- **端侧推理**：MindSpore Lite Kit
- **视觉能力**：CoreVision Kit
- **相机能力**：Camera Kit
- **图像能力**：Image Kit
- **模型框架**：YOLO11 分类模型
- **训练环境**：Colab / Python / Ultralytics
- **模型部署格式**：`best.pt -> best.onnx -> best.ms`

## 4. 系统架构

### 4.1 总体架构
系统采用“采集层 - 视觉分析层 - 推理层 - 业务判定层 - 展示层”的分层设计。

```text
┌──────────────────────────────────────────────────────────────┐
│                         ArkUI 展示层                         │
│  Index / Test / History / HistoryDetail / Information      │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                        业务控制与服务层                       │
│          CameraService + AiModelManager + 历史记录管理        │
└──────────────────────────────────────────────────────────────┘
               │                         │
               │                         │
               ▼                         ▼
┌──────────────────────────┐   ┌──────────────────────────────┐
│       Camera Kit         │   │      CoreVision Kit          │
│  相机预览 / 取帧 / 权限   │   │ OCR(textRecognition)         │
│  ImageReceiver / Surface │   │ 目标检测(objectDetection)     │
└──────────────────────────┘   └──────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────┐
│                     MindSpore Lite 推理层                     │
│            加载 best.ms -> 预处理 -> predict -> 输出解析      │
└──────────────────────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────┐
│                        训练与模型资产层                       │
│      dataset_split.py / args.yaml / results.csv / weights   │
└──────────────────────────────────────────────────────────────┘
```

### 4.2 当前系统的功能分工
- **ArkUI 页面层**：负责页面跳转、检测状态展示、历史记录查看、使用说明呈现
- **CameraService**：负责相机权限申请、相机预览输出、实时帧提取与节流
- **AiModelManager**：负责模型初始化、图像预处理、MindSpore Lite 推理、OCR 信息提取、位置偏差计算与结果融合
- **CoreVision Kit**：负责 OCR 文本识别与通用目标检测
- **MindSpore Lite**：负责运行训练后转换得到的分类模型

### 4.3 当前算法架构
当前版本采用的是**单分类模型 + OCR + 通用目标检测辅助**的混合方案：

1. 分类模型负责输出 25 个类别之一
2. OCR 负责读取标签中的文字型号与等级
3. 通用目标检测负责辅助获取纸箱与标签的位置框
4. 业务逻辑负责融合三者结果，得到最终“合格/不合格”判定

这意味着当前系统中的 `position_error` 既来自分类模型类别，也会受到目标位置分析结果的影响。

## 5. 项目结构说明

### 5.1 项目根目录结构
```text
.
├── AppScope/                                # 应用级资源与配置
├── entry/                                   # 主业务模块
├── YOLO_DataTraining/                       # 模型训练、导出与实验结果
├── .gitignore
├── .gitattributes
└── README.md
```

### 5.2 `entry/src` 完整结构说明
根据当前项目实际文件结构，`entry/src` 是 OpenHarmony 业务代码主体，共包含 `13` 个 `.ets` 文件、`3` 个 `.json5` 文件。

```text
entry/src
├── main/
│   ├── ets/
│   │   ├── entryability/
│   │   │   └── EntryAbility.ets
│   │   ├── entrybackupability/
│   │   │   └── EntryBackupAbility.ets
│   │   ├── model/
│   │   │   └── AiModelManager.ets
│   │   ├── pages/
│   │   │   ├── Index.ets
│   │   │   ├── Test.ets
│   │   │   ├── History.ets
│   │   │   ├── HistoryDetail.ets
│   │   │   └── Information.ets
│   │   └── services/
│   │       └── CameraService.ets
│   ├── resources/
│   │   ├── base/
│   │   │   ├── element/
│   │   │   ├── media/
│   │   │   └── profile/
│   │   ├── dark/
│   │   │   └── element/
│   │   └── rawfile/
│   │       └── best.ms
│   └── module.json5
├── mock/
│   └── mock-config.json5
├── ohosTest/
│   ├── ets/test/
│   └── module.json5
└── test/
    ├── List.test.ets
    └── LocalUnit.test.ets
```

### 5.3 `entry/src/main/ets` 各目录作用

#### `entryability/`
- **作用**：应用主入口能力
- **核心文件**：`EntryAbility.ets`
- **主要职责**：
  - 应用启动时创建 UIAbility
  - 设置窗口全屏布局
  - 设置状态栏文字颜色
  - 加载入口页面 `pages/Index`

#### `entrybackupability/`
- **作用**：应用备份扩展能力
- **核心文件**：`EntryBackupAbility.ets`
- **主要职责**：
  - 提供备份与恢复生命周期入口
  - 当前实现较轻量，主要用于满足 OpenHarmony 模块化能力结构

#### `model/`
- **作用**：AI 模型集成层
- **核心文件**：`AiModelManager.ets`
- **主要职责**：
  - 从 `rawfile/best.ms` 加载训练好的 MindSpore Lite 模型
  - 执行图像预处理
  - 调用模型执行分类推理
  - 解析 25 类分类结果
  - 调用 OCR 识别文本
  - 调用目标检测分析位置偏移
  - 将 AI 输出转成业务可读结果

#### `services/`
- **作用**：底层服务封装层
- **核心文件**：`CameraService.ets`
- **主要职责**：
  - 请求相机权限
  - 创建预览会话
  - 启动相机预览
  - 通过 `ImageReceiver` 获取实时帧
  - 将 JPEG 图像转成 PixelMap
  - 将 PixelMap 回调给上层页面

#### `pages/`
- **作用**：界面交互层
- **包含页面数**：5 个
- **页面说明**：
  - `Index.ets`：首页，提供“智能检测”“历史记录”“使用说明”三大入口
  - `Test.ets`：核心检测页面，承接相机预览、实时推理、结果显示、识别框绘制、历史记录写入
  - `History.ets`：历史记录列表页，展示检测结果概览
  - `HistoryDetail.ets`：历史记录详情页，展示单条检测数据明细
  - `Information.ets`：使用说明页，为终端用户提供操作流程与注意事项

### 5.4 `entry/src/main/resources` 各目录作用

#### `base/element/`
- 存放颜色、尺寸、字符串等基础资源定义

#### `base/media/`
- 存放 logo、启动图标、背景图等界面资源

#### `base/profile/`
- 存放页面清单和备份配置
- `main_pages.json` 指定主页面列表
- `backup_config.json` 提供备份配置资源

#### `dark/element/`
- 提供暗色模式下的资源覆盖配置

#### `rawfile/`
- 存放不经资源编译加工、直接以原始文件形式读取的模型文件
- 当前部署模型为 `best.ms`

### 5.5 `entry/src` 其他目录作用

#### `main/module.json5`
- 模块配置文件
- 定义应用入口能力、页面列表、权限声明、设备类型等
- 当前项目声明了 `ohos.permission.CAMERA`

#### `mock/`
- 模拟数据或调试环境相关配置目录

#### `ohosTest/`
- OpenHarmony 测试目录
- 用于集成测试或能力测试

#### `test/`
- 本地单元测试目录
- 主要用于通用组件或逻辑测试样例

## 6. 项目核心页面与模块说明

### 6.1 首页 `Index.ets`
首页使用 `Navigation + NavPathStack` 构建页面路由，属于整个项目的导航枢纽。主要提供：
- 进入智能检测页
- 进入历史记录页
- 进入使用说明页

### 6.2 检测页 `Test.ets`
这是整个系统的核心页面，承担了从实时画面到 AI 结果上屏的主流程：
- 初始化模型
- 获取相机预览 Surface
- 调用 `CameraService` 启动相机
- 接收 PixelMap 回调
- 调用 `AiModelManager.runInference()`
- 将识别结果显示到页面
- 将结果写入历史记录

### 6.3 历史页 `History.ets`
- 从 `@StorageLink('globalHistoryList')` 中读取历史数据
- 使用列表卡片样式展示产品型号、能效等级、缺陷类型、合格状态
- 点击后跳转到详情页

### 6.4 历史详情页 `HistoryDetail.ets`
- 展示单次检测的完整字段
- 包括产品型号、编号、结果、能效等级、缺陷类型、位置偏移量等

### 6.5 说明页 `Information.ets`
- 面向使用者展示操作步骤、状态说明与注意事项
- 是项目落地展示中非常重要的产品化补充页面

## 7. 项目统计

### 7.1 代码结构统计
| 项目 | 数量 |
| --- | ---: |
| `entry/src` 下 `.ets` 文件数 | 13 |
| `entry/src` 下 `.json5` 文件数 | 3 |
| `main/ets/pages` 页面文件数 | 5 |
| `main/ets/services` 服务文件数 | 1 |
| `main/ets/model` 模型管理文件数 | 1 |
| `main/ets/entryability` 入口能力文件数 | 1 |
| `main/ets/entrybackupability` 备份能力文件数 | 1 |

### 7.2 数据集总体统计
数据集路径：`YOLO_DataTraining/content/drive/MyDrive/dataset0318`

| 数据集划分 | 数量 |
| --- | ---: |
| Train | 984 |
| Val | 272 |
| Test | 169 |
| Total | 1425 |
| Classes | 25 |

### 7.3 按能效等级统计
| 能效等级 | 样本总数 |
| --- | ---: |
| Level 1 | 291 |
| Level 2 | 284 |
| Level 3 | 284 |
| Level 4 | 284 |
| Level 5 | 282 |

### 7.4 按缺陷类型统计
| 状态类型 | 样本总数 |
| --- | ---: |
| normal | 794 |
| damage | 185 |
| position_error | 111 |
| stain | 169 |
| wrinkle | 166 |

### 7.5 25 类详细分布
| 类别 | Train | Val | Test | Total |
| --- | ---: | ---: | ---: | ---: |
| `level1_damage` | 28 | 8 | 5 | 41 |
| `level1_normal` | 111 | 31 | 17 | 159 |
| `level1_position_error` | 16 | 4 | 4 | 24 |
| `level1_stain` | 23 | 6 | 5 | 34 |
| `level1_wrinkle` | 23 | 6 | 4 | 33 |
| `level2_damage` | 25 | 7 | 4 | 36 |
| `level2_normal` | 108 | 31 | 16 | 155 |
| `level2_position_error` | 18 | 5 | 3 | 26 |
| `level2_stain` | 23 | 6 | 4 | 33 |
| `level2_wrinkle` | 23 | 6 | 5 | 34 |
| `level3_damage` | 25 | 7 | 5 | 37 |
| `level3_normal` | 108 | 31 | 16 | 155 |
| `level3_position_error` | 17 | 5 | 3 | 25 |
| `level3_stain` | 23 | 6 | 5 | 34 |
| `level3_wrinkle` | 23 | 6 | 4 | 33 |
| `level4_damage` | 25 | 7 | 5 | 37 |
| `level4_normal` | 110 | 31 | 17 | 158 |
| `level4_position_error` | 15 | 4 | 3 | 22 |
| `level4_stain` | 23 | 6 | 5 | 34 |
| `level4_wrinkle` | 23 | 6 | 4 | 33 |
| `level5_damage` | 23 | 6 | 5 | 34 |
| `level5_normal` | 116 | 33 | 18 | 167 |
| `level5_position_error` | 9 | 2 | 3 | 14 |
| `level5_stain` | 23 | 6 | 5 | 34 |
| `level5_wrinkle` | 23 | 6 | 4 | 33 |

## 8. 类别体系设计
当前项目采用 25 分类体系，将“能效等级”和“标签状态”直接编码到同一个类别中。

| 能效等级 | 破损 | 正常 | 位置错误 | 污渍 | 褶皱 |
| --- | --- | --- | --- | --- | --- |
| 1 级 | `level1_damage` | `level1_normal` | `level1_position_error` | `level1_stain` | `level1_wrinkle` |
| 2 级 | `level2_damage` | `level2_normal` | `level2_position_error` | `level2_stain` | `level2_wrinkle` |
| 3 级 | `level3_damage` | `level3_normal` | `level3_position_error` | `level3_stain` | `level3_wrinkle` |
| 4 级 | `level4_damage` | `level4_normal` | `level4_position_error` | `level4_stain` | `level4_wrinkle` |
| 5 级 | `level5_damage` | `level5_normal` | `level5_position_error` | `level5_stain` | `level5_wrinkle` |

这种设计的优点是部署简单、推理链路短；缺点是“能效等级”和“位置错误”耦合在同一个分类模型中，后续若要提升位置偏移判断的鲁棒性，建议拆分为多模型架构。

## 9. 系统运行全流程

### 9.1 从应用启动到页面显示
1. 应用启动后，`EntryAbility.ets` 创建主能力
2. 主窗口设置为全屏沉浸式布局
3. 系统加载主页面 `pages/Index`
4. 用户点击“智能检测”进入 `Test.ets`

### 9.2 从拍摄画面到最终结果的完整数据流
下面是系统最关键的“图像进入后到底怎么走”的过程：

```text
用户点击开始检测
    ↓
Test.ets 调用 CameraService.startRealtimeDetection()
    ↓
CameraService 监听 imageArrival 事件
    ↓
ImageReceiver 取出 JPEG 图像帧
    ↓
通过 Image Kit 转换为 PixelMap
    ↓
回调给 Test.ets
    ↓
Test.ets 对画面做方向判断，必要时 rotate(90)
    ↓
Test.ets 调用 AiModelManager.runInference(pixelMap)
    ↓
AiModelManager 并行执行三类工作
    1. OCR 识别型号与等级
    2. 目标检测分析标签位置
    3. MindSpore Lite 分类模型推理
    ↓
AiModelManager 将三路结果融合
    ↓
返回 AiParsedResult
    ↓
Test.ets 更新识别框、文本结果、状态颜色、历史记录
    ↓
History / HistoryDetail 页面可查看归档结果
```

### 9.3 当前检测页内的实际执行步骤
1. 页面 `aboutToAppear()` 时加载 `best.ms`
2. XComponent 加载后获取相机预览 Surface
3. `CameraService` 请求相机权限并开启会话
4. 用户点击“开始检测”
5. 系统进入实时帧回调状态
6. 通过帧节流机制降低推理频率
7. 每次到达处理帧时，调用 `runAiModelInference()`
8. 推理结果用于更新 UI，并将结果写入历史列表

## 10. CameraService 调用过程
`CameraService.ets` 是整个系统中“相机到 PixelMap”这一链路的封装者。

### 10.1 启动相机的流程
1. `checkAndStartCamera()` 请求 `ohos.permission.CAMERA`
2. 获取 `CameraManager`
3. 枚举可用摄像头
4. 获取支持的输出能力
5. 优先选择 1080p 的 16:9 预览分辨率
6. 创建 `ImageReceiver`
7. 创建 `CaptureSession`
8. 创建 `PreviewOutput`
9. 同时建立一个给屏幕显示、一个给 `ImageReceiver` 取帧的双输出通路
10. 提交配置并启动会话

### 10.2 图像取帧过程
1. 注册 `imageArrival` 回调
2. 每当新帧到达时调用 `readNextImage`
3. 获取 JPEG 组件缓冲区
4. 使用 `image.createPixelMap()` 转为 `PixelMap`
5. 将 `PixelMap` 回调给上层页面

### 10.3 节流策略
当前代码采用帧计数方式节流：
- `CameraService` 中每到一帧就累加 `frameCount`
- 非目标帧直接释放
- 这样可以减轻模型推理压力，保证界面不卡顿

## 11. MindSpore Lite 调用过程

### 11.1 系统如何调用 MindSpore Lite
项目通过 `@kit.MindSporeLiteKit` 引入 MindSpore Lite 推理能力，在 `AiModelManager.ets` 中统一管理。

整体调用过程如下：

```text
读取 rawfile/best.ms
    ↓
getRawFileContent('best.ms')
    ↓
获得模型二进制 buffer
    ↓
构造 Context（当前 target = ['cpu']）
    ↓
mindSporeLite.loadModelFromBuffer(buffer, context)
    ↓
得到 model 实例
    ↓
model.getInputs()
    ↓
inputs[0].setData(inputTensorBuffer)
    ↓
model.predict(inputs)
    ↓
读取输出张量
    ↓
解析为 25 类分类结果
```

### 11.2 模型初始化过程
在 `AiModelManager.initModel()` 中：
1. 通过资源管理器读取 `best.ms`
2. 创建 `mindSporeLite.Context`
3. 指定运行目标为 CPU
4. 使用 `loadModelFromBuffer()` 完成模型实例化

### 11.3 输入预处理过程
在 `preprocessPixelMap()` 中完成以下操作：
1. 获取原始图像信息
2. 将图像缩放到 `224 x 224`
3. 从 PixelMap 读取 RGBA 数据
4. 丢弃 Alpha 通道，仅保留 RGB
5. 将像素值归一化到 `0~1`
6. 构造成 `Float32Array`

### 11.4 调用训练好的模型的过程
这部分正是“MindSpore Lite 如何调用训练好的模型”的核心：

1. 训练阶段得到 `best.pt`
2. 将 `best.pt` 导出成 `best.onnx`
3. 将 `best.onnx` 转换成 MindSpore Lite 可部署格式 `best.ms`
4. 把 `best.ms` 放到 `entry/src/main/resources/rawfile/`
5. 运行时由 OpenHarmony 应用读取该文件
6. `AiModelManager` 加载并实例化模型
7. 摄像头图像经预处理后写入模型输入张量
8. 模型输出 25 维分类结果
9. 根据最大值所在下标映射到 `CLASS_MAP`
10. 再拆分出能效等级与缺陷类型

### 11.5 输出解析过程
在 `parseOutput()` 中：
- 遍历输出数组
- 找出最大置信度及其索引
- 通过 `CLASS_MAP` 找到类别名
- 例如 `level3_stain`
- 再拆分成：
  - `energyLevel = 3`
  - `defectType = stain`
  - `defectTypeCn = 污渍`

## 12. OCR 与位置分析过程

### 12.1 OCR 过程
`AiModelManager.getModelByOcr()` 调用 `textRecognition.recognizeText()`：
- 读取整张图中的文本
- 通过正则提取“X级”
- 通过关键词“规格型号”截取后续文本
- 解析出产品型号字符串

### 12.2 文字校验过程
系统维护了一个 `PRESET_STANDARDS` 预设映射表：
- 键：产品型号
- 值：标准能效等级

OCR 得到型号后，会与预设标准进行比对：
- 若型号不存在于预设表，返回“型号未预设”
- 若等级不一致，返回“不匹配”
- 若一致，返回“校验合格”

### 12.3 位置分析过程
当前版本调用 `objectDetection.ObjectDetector.create()`：
- 对画面做通用目标检测
- 从检测结果中筛选高置信度对象
- 选择面积较大的两个目标作为纸箱与标签
- 计算两个中心点距离
- 若距离大于 `POSITION_ERROR_THRESHOLD = 150`，则判定为位置异常

## 13. 训练全流程详解

### 13.1 训练相关文件说明
训练资源主要位于 `YOLO_DataTraining/`：

```text
YOLO_DataTraining/
├── content/drive/MyDrive/dataset0318/   # 数据集
├── dataset_split.py                     # 数据集划分脚本
├── To_onnx.py                           # ONNX 导出脚本
├── yolo_cls_25cls/
│   ├── args.yaml                        # 训练参数
│   ├── results.csv                      # 训练指标
│   ├── results.png                      # 训练曲线图
│   ├── confusion_matrix.png             # 混淆矩阵
│   ├── confusion_matrix_normalized.png  # 归一化混淆矩阵
│   ├── train_batch*.jpg                 # 训练样本可视化
│   ├── val_batch*.jpg                   # 验证样本可视化
│   └── weights/
│       ├── best.pt
│       ├── last.pt
│       ├── best.onnx
│       └── best_ms.ms
└── yolov11_ ENERGY LABEL.ipynb          # 训练记录 Notebook
```

### 13.2 数据集划分脚本 `dataset_split.py`
该脚本用于在训练前对分类数据集进行再划分，核心特点如下：
- 划分比例：`0.7 / 0.2 / 0.1`
- 支持图像去重
- 支持按哈希保证文件唯一性
- 支持备份原数据集
- 支持保证小样本类别在 train/val/test 中都尽可能保留

### 13.3 训练配置 `args.yaml`
当前训练记录中的关键参数如下：

| 参数 | 值 |
| --- | --- |
| `task` | `classify` |
| `mode` | `train` |
| `model` | `yolo11x-cls.pt` |
| `data` | `/content/drive/MyDrive/dataset0318` |
| `epochs` | `300` |
| `patience` | `20` |
| `imgsz` | `224` |
| `batch` | `-1` |
| `cache` | `true` |
| `workers` | `8` |
| `pretrained` | `true` |
| `optimizer` | `auto` |
| `amp` | `true` |
| `deterministic` | `true` |
| `lr0` | `0.01` |
| `lrf` | `0.01` |
| `momentum` | `0.937` |
| `weight_decay` | `0.0005` |
| `warmup_epochs` | `3.0` |

### 13.4 数据增强参数
训练中启用了 YOLO 分类默认增强与部分几何增强：

| 参数 | 值 |
| --- | --- |
| `hsv_h` | `0.015` |
| `hsv_s` | `0.7` |
| `hsv_v` | `0.4` |
| `translate` | `0.1` |
| `scale` | `0.5` |
| `fliplr` | `0.5` |
| `flipud` | `0.0` |
| `mosaic` | `1.0` |

### 13.5 训练过程表现
结合 `results.csv`，模型在训练中表现出较快的收敛速度：
- 第 1 轮 Top-1 准确率约为 `5.5%`
- 第 20 轮 Top-1 准确率达到 `75.0%`
- 第 25 轮 Top-1 准确率达到 `92.65%`
- 第 28 轮 Top-5 准确率已达到 `100%`
- 第 38 轮 Top-1 准确率达到约 `98.16%`
- 第 39 轮验证损失降到约 `0.12891`

从当前结果文件可看出，模型在中前期快速收敛，后期进入高精度稳定阶段，并保存了最优权重 `best.pt`。

### 13.6 模型导出过程
导出脚本 `To_onnx.py` 的逻辑非常直接：

```python
from ultralytics import YOLO
model = YOLO(r"...\\weights\\best.pt")
model.export(format='onnx', imgsz=224, opset=12, dynamic=False)
```

导出链路如下：
1. 训练得到 `best.pt`
2. 通过 `To_onnx.py` 导出为 `best.onnx`
3. 再用 MindSpore Lite 转换工具导出为 `best_ms.ms`
4. 将最终部署模型复制为 `entry/src/main/resources/rawfile/best.ms`

### 13.7 当前训练链路总结
```text
原始分类数据集
    ↓
dataset_split.py 划分 train / val / test
    ↓
Colab 中运行 YOLO 分类训练
    ↓
输出 best.pt / last.pt / results.csv / confusion_matrix.png
    ↓
To_onnx.py 导出 best.onnx
    ↓
MindSpore Lite Converter 转换 best.ms
    ↓
复制到 OpenHarmony 工程 rawfile
    ↓
端侧加载运行
```

## 14. 当前系统的优点与局限

### 14.1 优点
- OpenHarmony 原生能力集成度高
- 端侧闭环完整，具备展示与实用价值
- 模型部署链路清晰
- 页面结构完整，有首页、检测页、历史页、说明页
- 检测结果不仅有分类结论，还有 OCR 和位置分析结果

### 14.2 当前局限
- `position_error` 目前仍混在分类模型类别中，解释性和鲁棒性有限
- OCR 型号校验依赖硬编码预设表，尚未接入外部产品数据库
- 历史记录当前为页面级存储，尚未做持久化数据库落地
- 目标检测部分使用的是通用视觉能力，不是针对纸箱与标签专门训练的检测模型

## 15. 路线图与后续展望
为了让系统更接近工业现场可落地方案，建议后续升级为**多模型架构**：

- **分类模型**：负责识别能效等级与表面缺陷
- **检测模型**：专门负责检测纸箱与能效标签位置，服务于 `position_error`

### 15.1 推荐的多模型方案

#### 模型一：分类模型
负责：
- 能效等级识别
- 破损识别
- 污渍识别
- 褶皱识别
- 正常/异常粗分类

#### 模型二：检测模型
负责：
- 检测产品盒子位置
- 检测能效标签位置
- 通过坐标关系判断是否“位置偏移”

这样做的好处是：
- “等级/缺陷”与“空间位置”解耦
- 位置异常不再依赖分类模型记忆背景
- 结果更可解释，便于答辩和工程落地

## 16. `position_error` 专用检测模型路线图
这是后续最值得落地的一条路线，建议在 README 和答辩中重点强调。

### 16.1 目标
让检测模型只做一件事：**同时输出产品盒子坐标和能效标签坐标**，然后由代码计算“标签相对盒子的偏移比例”，从而判断是否属于位置错误。

### 16.2 设计思想
- **分类模型**：继续负责能效等级、破损、污渍、褶皱等内容
- **检测模型**：专门负责 `position_error`
- **业务逻辑**：根据检测框坐标计算偏移比例

### 16.3 你必须做的标注要求
使用 LabelImg 对图片进行双类别检测标注，规则如下：

#### 必须做的事
- 所有图片都标，不管位置是否正常
- 每张图片必须框两个目标
- 框选产品盒子，类别名固定为：`product_box`
- 框选能效标签，类别名固定为：`energy_label`

#### 不需要做的事
- 不需要把检测类别写成 `normal` 或 `position_error`
- 不需要把位置正确与否写进标签名
- 不需要让标注阶段直接判断偏移

#### 标注原则
- 只做“物体框选”
- 位置是否错误，由后处理代码判断，不由人工标注类别承担

### 16.4 训练目标
训练一个 **YOLO 双类别检测模型**，让模型只学习两个物体：
- `product_box`
- `energy_label`

### 16.5 代码判断逻辑
检测模型推理后，程序拿到两个框：
- 盒子框坐标
- 标签框坐标

然后计算：
- 标签中心点
- 盒子中心点
- 标签相对于盒子中心的偏移比例

偏移比例小：
- 判定为位置正常

偏移比例大：
- 判定为位置错误

### 16.6 一个可落地的偏移比例公式
可以采用如下任一方式：

#### 方案 A：按盒子宽高归一化
```text
offset_x_ratio = abs(label_cx - box_cx) / box_w
offset_y_ratio = abs(label_cy - box_cy) / box_h
```

当：
- `offset_x_ratio < 阈值`
- 且 `offset_y_ratio < 阈值`

则认为位置正常，否则位置错误。

#### 方案 B：按盒子对角线归一化
```text
distance = sqrt((label_cx - box_cx)^2 + (label_cy - box_cy)^2)
ratio = distance / sqrt(box_w^2 + box_h^2)
```

这种方式更适合不同尺寸盒子间的统一阈值判定。

## 17. `position_error` 检测模型超详细实操步骤

### 步骤 1：准备图片
- 收集所有正常图片和位置错误图片
- 保证图片中尽量都能看到产品盒子和能效标签
- 建议保留不同角度、不同光照、不同距离的样本

### 步骤 2：使用 LabelImg 标注
直接照下面做：

1. 打开 LabelImg
2. 加载所有图片
3. 每张图标两个矩形框
4. 第一个框标产品盒子，类别名：`product_box`
5. 第二个框标能效标签，类别名：`energy_label`
6. 保存为 YOLO 格式 `txt`

请注意：
- 正常图也要标
- 位置错误图也要标
- 所有图都统一按这两个类别标
- 不要标 `normal`
- 不要标 `position_error`

### 步骤 3：组织检测数据集目录
建议整理成如下结构：

```text
position_dataset/
├── images/
│   ├── train/
│   ├── val/
│   └── test/
└── labels/
    ├── train/
    ├── val/
    └── test/
```

### 步骤 4：编写 `data.yaml`
```yaml
path: /content/drive/MyDrive/position_dataset
train: images/train
val: images/val
test: images/test

names:
  0: product_box
  1: energy_label
```

### 步骤 5：在 Colab 训练 YOLO 双类别检测模型
可参考命令：

```bash
yolo task=detect mode=train \
  model=yolo11n.pt \
  data=/content/drive/MyDrive/position_dataset/data.yaml \
  imgsz=640 \
  epochs=100 \
  batch=16 \
  project=energy_label_position_detect \
  name=yolo_detect_box_label
```

### 步骤 6：得到检测模型权重
训练完成后会得到：
- `best.pt`
- `last.pt`
- `results.csv`
- `confusion_matrix.png`

### 步骤 7：导出为 ONNX
```python
from ultralytics import YOLO
model = YOLO('best.pt')
model.export(format='onnx', imgsz=640, opset=12, dynamic=False)
```

### 步骤 8：转换为 MindSpore Lite 模型
将检测模型的 ONNX 文件进一步转换为 `.ms`，用于 OpenHarmony 端部署。

### 步骤 9：在工程中新增检测模型管理器
建议后续新增：
- `AiPositionModelManager.ets`

专门负责：
- 加载检测模型
- 输出 `product_box` 和 `energy_label` 两类框
- 计算偏移比例
- 单独返回 `isPositionCorrect`

### 步骤 10：在业务逻辑中融合双模型结果
最终流程建议变成：

```text
相机取帧
    ↓
分类模型：识别等级 + 破损/污渍/褶皱
    ↓
检测模型：识别盒子框 + 标签框
    ↓
代码计算偏移比例
    ↓
融合 OCR 结果
    ↓
输出最终结论
```

## 18. 快速运行说明

### 18.1 开发环境
- DevEco Studio
- OpenHarmony SDK
- 支持相机的 OpenHarmony 设备

### 18.2 运行步骤
1. 使用 DevEco Studio 打开项目
2. 检查 `entry/src/main/resources/rawfile/best.ms` 是否存在
3. 连接 OpenHarmony 设备
4. 编译并运行
5. 进入首页点击“智能检测”
6. 对准产品标签开始实时检测

### 18.3 结果查看
- 检测页查看实时结果
- 历史记录页查看历史归档
- 历史详情页查看单次记录详情

## 19. 项目亮点总结
- 基于 OpenHarmony 原生能力实现工业质检场景应用
- 完成了从训练、导出、转换到端侧部署的完整闭环
- 同时融合分类模型、OCR、位置分析三种能力
- 页面结构完整，具备可展示、可讲解、可扩展的工程形态
- 已具备进一步演进到多模型工业检测架构的基础

## 20. 后续可继续优化的方向
- 将历史记录接入数据库实现持久化
- 用专用检测模型替代通用目标检测做位置判断
- 支持更多型号预设与云端配置同步
- 支持检测图片留档与结果导出
- 支持多设备协同与产线批量质检

---

项目结语与愿景：
1. **工程闭环完整**：从数据集、训练、模型转换到 OpenHarmony 部署全部打通  
2. **业务价值明确**：解决能效标签识别、缺陷检测、位置校验三类实际问题  
3. **路线图清晰**：当前版本已可运行，下一步将升级为“分类模型 + 检测模型”的双模型工业方案
