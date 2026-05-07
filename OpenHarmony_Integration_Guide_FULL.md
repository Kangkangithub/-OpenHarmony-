# OpenHarmony 项目集成 MindSpore Lite 模型完整指南

本指南提供了将 `best_ms.ms` 模型集成到 OpenHarmony 工程中的**完整、可运行代码段**。

## 1. 工程目录结构
请确保你的工程目录包含以下关键部分：
```text
entry/
├── src/main/
│   ├── cpp/                # C++ 源代码目录
│   │   ├── CMakeLists.txt  # 完整编译配置
│   │   ├── infer_napi.cpp  # 完整 NAPI 推理实现
│   │   └── types/libentry/
│   │       └── index.d.ts  # NAPI 接口声明
│   ├── ets/                # ArkTS 代码
│   │   ├── utils/
│   │   │   └── Preprocess.ets # 完整图像预处理工具
│   │   └── pages/
│   │       └── Index.ets   # UI 调用示例
│   └── resources/
│       └── rawfile/        # 存放 best_ms.ms
```

- 在 DevEco Studio 中按照指南中的 目录结构 创建对应的文件。
- 将代码分别粘贴到 infer_napi.cpp 、 Preprocess.ets 等文件中。
- 确保 best_ms.ms 模型已放入 resources/rawfile 目录下。
- 运行项目，通过 runInference 接口即可获取识别结果。
---

## 2. 完整代码实现

### 第一步：NAPI 接口声明 (`index.d.ts`)
在 `entry/src/main/cpp/types/libentry/index.d.ts` 中定义接口：

```typescript
export const initModel: (modelPath: string) => boolean;
export const doInference: (buffer: ArrayBuffer) => number;
```

### 第二步：CMake 配置 (`CMakeLists.txt`)
在 `entry/src/main/cpp/CMakeLists.txt` 中配置 MindSpore Lite 链接：

```cmake
cmake_minimum_required(VERSION 3.4.1)
project(EnergyLabelDetection)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_MODEL_DIRECTORY})

include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include)

# 查找 MindSpore Lite 动态库
find_library(mindspore-lib mindspore_lite_ndk)
find_library(hilog-lib hilog_ndk.z.so)
find_library(napi-lib ace_napi.z.so)

add_library(entry SHARED infer_napi.cpp)

target_link_libraries(entry PUBLIC 
    ${mindspore-lib} 
    ${hilog-lib} 
    ${napi-lib}
)
```

### 第三步：NAPI C++ 推理核心 (`infer_napi.cpp`)
这是完整的 C++ 实现，包含模型加载、内存管理和推理逻辑：

```cpp
#include <mindspore/model.h>
#include <mindspore/context.h>
#include "napi/native_api.h"
#include <hilog/log.h>
#include <vector>
#include <string>

// 定义日志标签
#undef LOG_TAG
#define LOG_TAG "MS_LITE_NAPI"
#undef LOG_DOMAIN
#define LOG_DOMAIN 0x0001

// 全局模型指针
static mindspore::Model *g_model = nullptr;

// 1. 初始化模型函数
static napi_value InitModel(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    // 获取模型路径字符串
    char path[256];
    size_t path_len;
    napi_get_value_string_utf8(env, args[0], path, 256, &path_len);

    // 配置上下文：使用 CPU 推理
    auto context = std::make_shared<mindspore::Context>();
    auto cpu_device_info = std::make_shared<mindspore::CPUDeviceInfo>();
    context->MutableDeviceInfo().push_back(cpu_device_info);

    // 创建并构建模型
    if (g_model != nullptr) {
        delete g_model;
    }
    g_model = new mindspore::Model();
    auto status = g_model->Build(path, mindspore::kMindIR, context);

    bool success = (status == mindspore::kSuccess);
    OH_LOG_INFO(LOG_APP, "Model Build Status: %{public}d", status);

    napi_value result;
    napi_get_boolean(env, success, &result);
    return result;
}

// 2. 执行推理函数
static napi_value DoInference(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    // 获取输入的 ArrayBuffer 数据
    void* data;
    size_t byte_length;
    napi_get_arraybuffer_info(env, args[0], &data, &byte_length);

    if (g_model == nullptr) {
        OH_LOG_ERROR(LOG_APP, "Model not initialized!");
        napi_value err_res;
        napi_create_int32(env, -1, &err_res);
        return err_res;
    }

    // 准备输入张量
    auto inputs = g_model->GetInputs();
    if (inputs.empty()) {
        napi_value err_res;
        napi_create_int32(env, -2, &err_res);
        return err_res;
    }
    
    auto input_tensor = inputs[0];
    memcpy(input_tensor.MutableData(), data, byte_length);

    // 执行推理
    std::vector<mindspore::MSTensor> outputs;
    auto status = g_model->Predict(inputs, &outputs);

    if (status != mindspore::kSuccess) {
        OH_LOG_ERROR(LOG_APP, "Inference failed with status: %{public}d", status);
        napi_value err_res;
        napi_create_int32(env, -3, &err_res);
        return err_res;
    }

    // 获取输出结果 (Top-1 分类)
    float* output_data = reinterpret_cast<float*>(outputs[0].MutableData());
    int max_idx = 0;
    float max_score = -1.0f;
    for (int i = 0; i < 25; i++) {
        if (output_data[i] > max_score) {
            max_score = output_data[i];
            max_idx = i;
        }
    }

    napi_value res_idx;
    napi_create_int32(env, max_idx, &res_idx);
    return res_idx;
}

// 模块注册
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        { "initModel", nullptr, InitModel, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "doInference", nullptr, DoInference, nullptr, nullptr, nullptr, napi_default, nullptr }
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

static napi_module energyModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = ((void*)0),
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) {
    napi_module_register(&energyModule);
}
```

### 第四步：ArkTS 图像预处理工具 (`Preprocess.ets`)
处理 PixelMap 转换为 YOLOv11 要求的 `[1, 3, 224, 224]` 归一化格式：

```typescript
import image from '@ohos.multimedia.image';

export class PreprocessUtils {
  /**
   * 将 PixelMap 转换为 Float32Array (RGB, CHW格式, [0, 1] 归一化)
   */
  static async preprocess(pixelMap: image.PixelMap): Promise<Float32Array> {
    const info = await pixelMap.getImageInfo();
    const width = info.size.width;
    const height = info.size.height;
    
    // 1. 读取原始 RGBA 数据
    const buffer = new ArrayBuffer(pixelMap.getPixelBytesNumber());
    await pixelMap.readPixelsToBuffer(buffer);
    const rgbaData = new Uint8Array(buffer);

    // 2. 目标尺寸 224x224 (假设传入的 PixelMap 已经由 ArkUI 缩放过)
    const targetW = 224;
    const targetH = 224;
    const float32Data = new Float32Array(3 * targetW * targetH);

    // 3. HWC (RGBA) -> CHW (RGB) 转换并归一化
    for (let h = 0; h < targetH; h++) {
      for (let w = 0; w < targetW; w++) {
        const rgbaIdx = (h * targetW + w) * 4;
        const rIdx = h * targetW + w;
        const gIdx = rIdx + targetW * targetH;
        const bIdx = rIdx + 2 * targetW * targetH;

        // 归一化到 [0, 1]
        float32Data[rIdx] = rgbaData[rgbaIdx] / 255.0;
        float32Data[gIdx] = rgbaData[rgbaIdx + 1] / 255.0;
        float32Data[bIdx] = rgbaData[rgbaIdx + 2] / 255.0;
      }
    }
    return float32Data;
  }
}
```

### 第五步：UI 调用示例 (`Index.ets`)
在主页面中加载模型并执行检测：

```typescript
import libNative from 'libentry.so';
import { PreprocessUtils } from '../utils/Preprocess';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';

@Entry
@Component
struct Index {
  @State resultText: string = "等待识别...";
  private context = getContext(this) as common.UIAbilityContext;

  const CLASS_NAMES = [
    "level1_damage","level1_normal","level1_position_error","level1_stain","level1_wrinkle",
    "level2_damage","level2_normal","level2_position_error","level2_stain","level2_wrinkle",
    "level3_damage","level3_normal","level3_position_error","level3_stain","level3_wrinkle",
    "level4_damage","level4_normal","level4_position_error","level4_stain","level4_wrinkle",
    "level5_damage","level5_normal","level5_position_error","level5_stain","level5_wrinkle"
  ];

  async aboutToAppear() {
    // 1. 将模型从 rawfile 拷贝到沙盒
    const modelName = "best_ms.ms";
    const destPath = this.context.filesDir + "/" + modelName;
    
    try {
      let data = await this.context.resourceManager.getRawFileContent(modelName);
      let file = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, data.buffer);
      fs.closeSync(file);
      
      // 2. 初始化模型
      let success = libNative.initModel(destPath);
      this.resultText = success ? "模型加载成功" : "模型加载失败";
    } catch (err) {
      console.error("Model load error: " + err);
    }
  }

  async runInference(pixelMap: image.PixelMap) {
    this.resultText = "正在识别...";
    
    // 1. 图像预处理
    const inputBuffer = await PreprocessUtils.preprocess(pixelMap);
    
    // 2. 执行推理
    const index = libNative.doInference(inputBuffer.buffer);
    
    if (index >= 0 && index < 25) {
      const name = this.CLASS_NAMES[index];
      const parts = name.split('_');
      this.resultText = `检测结果：能效等级 ${parts[0]}，状态 ${parts[1]}`;
    } else {
      this.resultText = "识别失败，错误码：" + index;
    }
  }

  build() {
    Column() {
      Text(this.resultText).fontSize(20).margin(20)
      // 此处添加图片选择或拍照组件，并获取 PixelMap
    }
  }
}
```

---

## 3. 核心技术总结
1.  **内存管理**: 在 NAPI 层使用 `napi_get_arraybuffer_info` 直接读取 ArkTS 传入的内存，避免大面积拷贝。
2.  **数据格式**: YOLOv11 训练时使用的 `imgsz=224` 和 `RGB` 格式，必须在预处理中严格对齐。
3.  **模型位置**: OpenHarmony 安全限制要求 C++ 只能访问沙盒路径（`filesDir`），因此必须执行 `rawfile` 到沙盒的拷贝动作。
