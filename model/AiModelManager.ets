import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { resourceManager } from '@kit.LocalizationKit';
import { image } from '@kit.ImageKit';
import { textRecognition , objectDetection, visionBase } from '@kit.CoreVisionKit';

interface OcrResult {
  model: string;
  level: number; // 提取到的能效等级数字
}

interface ValidationResult {
  isMatch: boolean;
  msg: string;
}

interface PositionResult {
  offset: number;
  isCorrect: boolean;
  boxes: BoxInfo[];
}

export interface BoxInfo {
  left: number;
  top: number;
  width: number;
  height: number;
  name: string;
}

// 预设信息
const PRESET_STANDARDS: Record<string, number> = {
  'DLR-H145W(G1)': 1,
  '': 1,
  'KFR-72LW': 1
};

const CLASS_MAP = [
  "level1_damage","level1_normal","level1_position_error","level1_stain","level1_wrinkle",
  "level2_damage","level2_normal","level2_position_error","level2_stain","level2_wrinkle",
  "level3_damage","level3_normal","level3_position_error","level3_stain","level3_wrinkle",
  "level4_damage","level4_normal","level4_position_error","level4_stain","level4_wrinkle",
  "level5_damage","level5_normal","level5_position_error","level5_stain","level5_wrinkle"
];

const DEFECT_TYPE_MAP: Record<string, string> = {
  "normal": "无缺陷",
  "damage": "破损",
  "stain": "污渍",
  "wrinkle": "褶皱",
  "position_error": "位置偏移"
};

// 设置距离阈值
const POSITION_ERROR_THRESHOLD = 150;

export interface AiParsedResult {
  energyLevel: number;
  defectTypeCn: string;
  hasDefect: boolean;
  inspectionRate: string;
  maxConfidence: number;
  productModel: string;     // 识别出的型号
  isModelMatched: boolean;  // 是否匹配预设
  validationMsg: string;    // 校验结果文案
  positionOffset: string;   // 计算出的距离文本
  isPositionCorrect: boolean;
  boxes: BoxInfo[];
}

export class AiModelManager {
  private model: mindSporeLite.Model | undefined = undefined;

  // 1. 初始化并加载模型
  async initModel(resMgr: resourceManager.ResourceManager) {
    try {
      // 从 rawfile 中读取模型文件到内存
      let modelBuffer = await resMgr.getRawFileContent('best.ms');

      // 配置运行上下文（指定使用 CPU 或 NPU 加速）
      let context: mindSporeLite.Context = {};
      context.target = ['cpu']; // 如果设备支持，可加上 'npu'

      // 创建模型实例
      this.model = await mindSporeLite.loadModelFromBuffer(modelBuffer.buffer, context);
      console.info('[AI] 模型加载成功！');
    } catch (e) {
      console.error('[AI] 模型加载失败: ' + JSON.stringify(e));
    }
  }

  private async checkLabelPosition(pixelMap: image.PixelMap): Promise<PositionResult> {
    try {
      let inputData: visionBase.InputData = { pixelMap: pixelMap };
      let request: visionBase.Request = { inputData: inputData };

      let detector = await objectDetection.ObjectDetector.create();
      let data = await detector.process(request);
      let validObjects = data.objects.filter(obj => obj.score > 0.4);
      if (validObjects.length < 2) {
        return { offset: 0, isCorrect: true, boxes: [] };
      }
      if (!data.objects || data.objects.length < 2) {
        return { offset: 0, isCorrect: true, boxes: [] };
      }

      let sortedObjects = data.objects.sort((a , b) => {
        let areaA = a.boundingBox.width * a.boundingBox.height;
        let areaB = b.boundingBox.width * b.boundingBox.height;
        return areaB - areaA;
      });

      let boxInfo = sortedObjects[0].boundingBox;
      let labelInfo = sortedObjects[1].boundingBox;

      let boxCenterX = boxInfo.left + boxInfo.width / 2;
      let boxCenterY = boxInfo.top + boxInfo.height / 2;

      let labelCenterX = labelInfo.left + labelInfo.width / 2;
      let labelCenterY = labelInfo.top + labelInfo.height / 2;

      let distance = Math.sqrt(Math.pow(boxCenterX - labelCenterX, 2) + Math.pow(boxCenterY - labelCenterY, 2));
      let isCorrect = distance <= POSITION_ERROR_THRESHOLD;

      let detectedBoxes: BoxInfo[] = [
        { left: boxInfo.left,
          top: boxInfo.top,
          width: boxInfo.width < boxInfo.height ? boxInfo.width : boxInfo.height,
          height: boxInfo.width < boxInfo.height ? boxInfo.height : boxInfo.width,
          name: "纸箱主件" },
        { left: labelInfo.left,
          top: labelInfo.top,
          width: labelInfo.width > labelInfo.height ? labelInfo.height : labelInfo.width,
          height: labelInfo.width > labelInfo.height ? labelInfo.width : labelInfo.height,
          name: "能效标签" }
      ];

      return { offset: distance, isCorrect: isCorrect, boxes: detectedBoxes };

    } catch (error) {
      console.error("[AI] 多目标识别失败: " + JSON.stringify(error));
      return { offset: 0, isCorrect: true, boxes: [] };
    }
  }

  private async getModelByOcr(pixelMap: image.PixelMap): Promise<OcrResult> {
    let finalResult: OcrResult = { model: "未知型号", level: 0 };
    try {
      let visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };
      let result = await textRecognition.recognizeText(visionInfo);
      let fullText = result.value;
      console.info('[AI] OCR 完整 : ' + fullText);
      const cleanText = fullText.replace(/\s+/g, ' ');
      console.info('[AI] OCR 选取 : ' + cleanText);
      let levelMatch = cleanText.match(/(\d)[\s]*级/);
      if (levelMatch) {
        finalResult.level = parseInt(levelMatch[1]);
        console.info('[AI] 等级: ' + finalResult.level);
      }

      const blacklist = ["股份有限公司", "有限公司", "生产者名称"];
      let keyword = "规格型号";
      let index = fullText.indexOf(keyword);
      if (index !== -1) {
        // 截取关键词之后的所有文本
        let subText = fullText.substring(index + keyword.length).replace(/\s+/g, ' ');
        // 3. 用正则在剩下的文本中找第一组像“型号”的组合
        // 匹配包含 字母+数字+连字符+括号 的字符串
        let modelMatch = subText.match(/(?=.*[A-Z])[A-Z0-9\-\(\)\/]{5,}/i);
        if (modelMatch) {
          let tempModel = modelMatch[0].trim();
          // 排除掉黑名单里的内容
          if (!blacklist.some(item => tempModel.includes(item))) {
            finalResult.model = tempModel;
          }
        }
      }
      return finalResult;
    } catch (e) {
      return finalResult;
    }
  }

  private validateMatch(detectedModel: string, detectedLevel: number): ValidationResult {
    const standardLevel = PRESET_STANDARDS[detectedModel];
    if (standardLevel === undefined) {
      return { isMatch: false, msg: "型号未预设" };
    }
    if (standardLevel !== detectedLevel) {
      return { isMatch: false, msg: `不匹配(预设为${standardLevel}级)` };
    }
    return { isMatch: true, msg: "校验合格" };
  }

  private async preprocessPixelMap(pixelMap: image.PixelMap): Promise<Float32Array> {
    // 1. 获取图片信息
    const info = await pixelMap.getImageInfo();

    // 2. 缩放至 224x224 (ArkTS 核心 API 使用 scale)
    await pixelMap.scale(224 / info.size.width, 224 / info.size.height);

    // 3. 读取像素数据 (假设模型需要 RGB，PixelMap 通常是 RGBA)
    // 准备一个足够大的 Buffer
    const bufferSize = 224 * 224 * 4;
    const readBuffer = new ArrayBuffer(bufferSize);
    await pixelMap.readPixelsToBuffer(readBuffer);

    const uint8Array = new Uint8Array(readBuffer);
    // 4. 手动归一化并剔除 Alpha 通道 (RGB 顺序)
    const float32Array = new Float32Array(224 * 224 * 3);
    for (let i = 0; i < 224 * 224; i++) {
      float32Array[i * 3] = uint8Array[i * 4] / 255.0;     // R
      float32Array[i * 3 + 1] = uint8Array[i * 4 + 1] / 255.0; // G
      float32Array[i * 3 + 2] = uint8Array[i * 4 + 2] / 255.0; // B
    }
    return float32Array;
  }

  // 2. 执行推理
  async runInference(pixelMap: image.PixelMap): Promise<AiParsedResult> {
    if (!this.model) throw new Error("模型未初始化");
    const productModel = await this.getModelByOcr(pixelMap);
    const positionData = await this.checkLabelPosition(pixelMap);
    // 1. 图像预处理
    const inputData = await this.preprocessPixelMap(pixelMap);
    // 2. 构造模型输入
    let inputs = this.model.getInputs();
    inputs[0].setData(inputData.buffer);
    // 3. 执行推理
    let outputs = await this.model.predict(inputs);
    let outputData = new Float32Array(outputs[0].getData());
    let result = this.parseOutput(outputData);
    if (positionData.boxes && positionData.boxes.length > 0) {
      positionData.boxes.forEach((box, index) => {
        console.info(`[Debug-AI输出] 序号: ${index}, 标签名: ${box.name}, 原始Left: ${box.left}, 原始Top: ${box.top}, 原始宽: ${box.width}, 原始高: ${box.height}`);
      });
    } else {
      console.warn("[Debug-AI输出] 未检测到任何目标框");
    }
    const validation = this.validateMatch(productModel.model, result.energyLevel);
    if (productModel.level !== 0 && productModel.level !== result.energyLevel) {
      validation.isMatch = false;
      validation.msg = `等级矛盾(文字为${productModel.level}级,实际为${result.energyLevel}级)`;
    }

    if (!positionData.isCorrect) {
      result.hasDefect = true;
      result.defectTypeCn = "位置偏移";
    }

    // 4. 核心解析逻辑
    return {
      energyLevel: result.energyLevel,
      defectTypeCn: result.defectTypeCn,
      hasDefect: result.hasDefect,
      inspectionRate: result.inspectionRate,
      maxConfidence: result.maxConfidence,
      productModel: productModel.model,
      isModelMatched: validation.isMatch,
      validationMsg: validation.msg,
      positionOffset: positionData.offset.toFixed(1) + "px",
      isPositionCorrect: positionData.isCorrect,
      boxes: positionData.boxes
    };
  }

  private parseOutput(rawResults: Float32Array): AiParsedResult {
    let maxConfidence = 0;
    let predictClassId = 0;
    for (let i = 0; i < rawResults.length; i++) {
      if (rawResults[i] > maxConfidence) {
        maxConfidence = rawResults[i];
        predictClassId = i;
      }
    }

    const predictClassName: string = CLASS_MAP[predictClassId];
    const parts: string[] = predictClassName.split('_');
    const levelStr: string = parts[0];
    const defectTypeEn: string = parts[1];

    const energyLevel: number = parseInt(levelStr.replace('level', ''));
    const defectTypeCn: string = DEFECT_TYPE_MAP[defectTypeEn] || "未知缺陷";
    const inspectionRate: string = (maxConfidence * 100).toFixed(2) + '%';
    const hasDefect: boolean = defectTypeEn !== "normal";

    return {
      energyLevel: energyLevel,
      defectTypeCn: defectTypeCn,
      hasDefect: hasDefect,
      inspectionRate: inspectionRate,
      maxConfidence: maxConfidence,
      productModel: "",
      isModelMatched: false,
      validationMsg: "",
      positionOffset: "0px",
      isPositionCorrect: true,
      boxes: []
    };
  }
}