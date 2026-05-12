import { window } from '@kit.ArkUI';
import {CameraService} from '../services/CameraService'
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { AiModelManager, AiParsedResult, BoxInfo } from '../model/AiModelManager';

export interface HistoryItem {
  productId: string;      // 产品编号
  productModel: string;   // 产品型号
  isQualified: boolean;   // 是否合格
  energyLevel?: number;
  energyLabel?: Resource; // 能效标签（可选）
  inspectionRate?: number; // 检验率（不合格时）
  hasDefect?: boolean;    // 缺陷与否（不合格时）
  defectType?: string;
  offset?: string;        // 位置偏移量（不合格时）
}

interface DetectionResult {
  label: string;
  value: string;
  visible?: boolean;
}

type EnergyLevelCallback = (energyLevel: number) => void;
type DrawBoxesCallback = (boxes: BoxInfo[]) => void;

@Component
export struct Test { // 加 export 才能被外部引用
  @Consume('pageStack') pageStack: NavPathStack;
  @State statusBarHeight: number = 0;
  @State isShowResult: boolean = false;
  @State currentPixelMap: image.PixelMap | undefined = undefined;
  @State frameCount: number = 0; // 用于节流的计数器
  @State isDetecting: boolean = false;
  @State detectResult: string = "等待检测...";
  @State results: DetectionResult[] = [
    { label: '缺陷与否', value: '等待中...' },
    { label: '偏移量', value: '等待中...'}
  ];
  @State isModelLoaded: boolean = false; // 【新增】模型加载状态
  @State loadingText: string = "模型加载中..."; // 【新增】加载文案
  @StorageLink('globalHistoryList') historyList: HistoryItem[] = [];

  @State drawBoxes: BoxInfo[] = [];
  @State xCompWidth: number = 1;
  @State xCompHeight: number = 1;

  // 在组件生命周期中获取真实高度
  async aboutToAppear() {
    window.getLastWindow(getContext(this)).then(win => {
      // 获取系统规避区域（状态栏）
      let avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      // 关键：将 px 转换为 vp 才能直接用于组件属性
      this.statusBarHeight = px2vp(avoidArea.topRect.height);
      console.info('状态栏高度已获取: ' + this.statusBarHeight);
    })

    // 2. 在页面初始化时，异步加载 AI 模型
    try {
      let context = getContext(this);
      await this.aiManager.initModel(context.resourceManager);
      this.isModelLoaded = true; // 加载完成
    } catch (e) {
      this.loadingText = "模型加载失败，请检查网络或资源";
      console.error("模型初始错误: " + e);
    }
  }
  private mController: XComponentController = new XComponentController()
  private cameraService: CameraService = new CameraService();
  private aiManager: AiModelManager = new AiModelManager(); // 实例化 AI 管理器
  private isInferring: boolean = false;
  build() {
    NavDestination() {
      Stack({alignContent:Alignment.Top}){
        Stack({ alignContent: Alignment.TopStart }) {
          XComponent({
            id: 'camera_preview_test',
            type: 'surface',
            controller: this.mController
          })
            .aspectRatio(9 / 16)
            .width('100%')
            .onAreaChange((oldValue: Area, newValue: Area) => {
              this.xCompWidth = Number(newValue.width);
              this.xCompHeight = Number(newValue.height);
            })
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
            .onLoad(async () => {
              let surfaceId = this.mController.getXComponentSurfaceId();
              let context = getContext(this) as common.UIAbilityContext;
              // 一键启动
              await this.cameraService.checkAndStartCamera(context, surfaceId);
            })
          ForEach(this.drawBoxes, (box: BoxInfo) => {
            Column() {
              // 标签名字（放在框上方）
              Text(box.name)
                .fontSize(12)
                .fontColor(Color.White)
                .backgroundColor(Color.Green)
                .padding({
                  left: 4,
                  right: 4,
                  top: 2,
                  bottom: 2
                })
                .position({ x: 0, y: -20 }) // 向上偏移
              // 识别框本体
              Rect()
                .width(box.width)
                .height(box.height)
                .fill(Color.Transparent)
                .stroke(Color.Green)
                .strokeWidth(3)
                .strokeDashArray([5, 5]) // 也可以换成虚线框
            }
            .position({ x: box.left, y: box.top }) // 绝对定位
            .width(box.width)
            .height(box.height)
          })
        }
        .width('100%')
        .aspectRatio(9/16)
        Column(){
          Row(){
            Image($r('sys.media.ohos_ic_back'))
              .width(28)
              .height(28)
              .fillColor(Color.White)
              .blendMode(BlendMode.DIFFERENCE, BlendApplyType.OFFSCREEN)
              .onClick(()=>{
                this.pageStack.pop()
              })
            Text('智能检测')
              .fontColor(Color.White)
              .blendMode(BlendMode.DIFFERENCE, BlendApplyType.OFFSCREEN)
              .fontSize(20)
              .margin({left:16})
          }
          .width('100%')
          .padding({ top: this.statusBarHeight + 20, left: 25 })

          Blank()

          if(this.isShowResult){
            Column(){
              ForEach(this.results,(item:DetectionResult)=>{
                if(item.visible !== false){
                  Row(){
                    Text(`${item.label} : `)
                      .fontSize(28)
                      .fontColor(Color.Black)
                      .fontWeight(FontWeight.Medium)
                      .margin({right:5 , top:10 , left:5})

                    Text(item.value)
                      .fontSize(28)
                      .fontColor(Color.Red)
                      .margin({top:10})
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Start)
                  .margin({bottom:10 ,left:15})
                }
              })
            }
            .alignItems(HorizontalAlign.Start)
            .width(350)
            .height(280)
            .justifyContent(FlexAlign.Center)
            .padding({ top: 10, bottom: 10 })
            .margin({
              bottom:30
            })
            .backgroundColor('rgba(255, 255, 255, 0.8)') // 半透明白色背景
            .borderRadius(15)
            .shadow({ radius: 20, color: 0x30000000 })
            .transition({ type: TransitionType.All, opacity: 0, scale: { x: 0.5, y: 0.5 } })
          }

          Button(){
            Row() {
              if (!this.isModelLoaded) {
                // 展示一个小型的加载环（鸿蒙内置组件）
                LoadingProgress()
                  .width(24)
                  .height(24)
                  .margin({ right: 12 })
                  .color(Color.White)
              }
              Text(this.isModelLoaded ? (this.isDetecting ? "停止检测" : "开始检测") : "加载中...")
                .fontSize(28) // 稍微调小一点，防止转圈圈挤不下
                .fontColor(Color.White)
            }
          }
          .width(200)
          .height(60)
          .backgroundColor(this.isModelLoaded ? (this.isDetecting ? Color.Orange : Color.Red) : Color.Gray)
          .enabled(this.isModelLoaded)
          .shadow({radius: 10, color: 0x20000000, offsetX: 5, offsetY: 5})
          .stateStyles({
            pressed:{
              .brightness(0.8)
              .scale({x:0.96 , y:0.96})
            },
            normal:{
              .brightness(1.0)
              .scale({ x: 1.0, y: 1.0 })
            }
          })
          .animation({ curve: Curve.Sharp, duration: 150 })
          .margin({
            bottom:40
          })
          .onClick(async ()=>{
            this.handleStartDetection()
            animateTo({duration:300}, ()=>{
              this.isShowResult = true;
            })
          })
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .clip(true)
      .backgroundColor(Color.Black)
    }
    .hideTitleBar(true)
    .onDisAppear(async ()=>{
      console.log('[UI] 页面销毁，准备释放资源');
      this.cameraService.stopDetection();
      await this.cameraService.releaseCamera();
    })
  }

  private async runAiModelInference(pixelMap: image.PixelMap, energyLevelCallback: EnergyLevelCallback, drawBoxesCallback: DrawBoxesCallback): Promise<DetectionResult[]> {
    try {
      // 先提取原始图片数据
      let imgInfo = await pixelMap.getImageInfo();
      let originalWidthPx = imgInfo.size.width;
      let originalHeightPx = imgInfo.size.height;
      if (originalWidthPx > originalHeightPx && this.xCompWidth < this.xCompHeight) {
        console.info('[AI] 检测到横向原始帧，正在将其旋转为竖直方向...');
        await pixelMap.rotate(90);
        imgInfo = await pixelMap.getImageInfo();
        originalWidthPx = imgInfo.size.width;
        originalHeightPx = imgInfo.size.height;
      }
      // 1. 调用底层获取解析好的对象
      let parsedData: AiParsedResult = await this.aiManager.runInference(pixelMap);

      // 2. 触发回调传递能效等级
      energyLevelCallback(parsedData.energyLevel);

      // 坐标系缩放
      let scaledBoxes: BoxInfo[] = parsedData.boxes.map(box => ({
        name: box.name,
        // 直接使用 组件宽度 / 图片宽度 计算出缩放比例，得出的结果天然就是 vp 单位
        left: box.left * (this.xCompWidth / originalWidthPx),
        top: box.top * (this.xCompHeight / originalHeightPx),
        width: box.width * (this.xCompWidth / originalWidthPx),
        height: box.height * (this.xCompHeight / originalHeightPx)
      } as BoxInfo));

      console.info(`[Debug] 手机屏幕尺寸(vp): ${this.xCompWidth} x ${this.xCompHeight}`);
      console.info(`[Debug] 图片物理像素(px): ${imgInfo.size.width} x ${imgInfo.size.height}`);

      // 触发回调更新 UI 框
      drawBoxesCallback(scaledBoxes);

      // 3. 组装 UI 渲染列表
      let finalResults: DetectionResult[] = [
        { label: '产品型号', value: parsedData.productModel } as DetectionResult,
        { label: '校验状态', value: parsedData.validationMsg } as DetectionResult ,
        { label: '缺陷与否', value: parsedData.hasDefect ? "不合格" : "合格" } as DetectionResult,
      ];

      if (parsedData.hasDefect) {
        finalResults.push({
          label: '缺陷类型',
          value: parsedData.defectTypeCn,
          visible: true
        } as DetectionResult);
      }

      finalResults.push({ label: '偏移量', value: parsedData.positionOffset });
      return finalResults;

    } catch (error) {
      console.error('推理出错', error);
      return [{ label: '状态', value: '推理失败' }];
    }
  }

  // 处理点击逻辑
  private handleStartDetection() {
    let currentEnergyLevel = 0; // 用来暂存回调传出来的能效等级
    if (this.isDetecting) {
      // 1. 如果正在检测，执行停止逻辑
      console.log('[UI] 停止检测');
      this.cameraService.stopDetection();
      this.isDetecting = false;
      this.isShowResult = false;
      return; // 结束执行
    }

    // 保持你原有的回调模式，仅用于接收 energyLevel
    const energyLevelCallback = (energyLevel: number) => {
      currentEnergyLevel = energyLevel;
    };

    const updateBoxesCallback: DrawBoxesCallback = (boxes: BoxInfo[]) => {
      this.drawBoxes = boxes;
    };

    this.isDetecting = true;
    console.log('[UI] 点击开始检测按钮');
    this.isShowResult = true;

    this.cameraService.startRealtimeDetection(async (pixelMap: image.PixelMap) => {
      this.frameCount++;

      // 保持你原有的节流机制 (每 10 帧处理一次)
      if (this.frameCount % 10 === 0) {
        if (this.isInferring) {
          pixelMap.release();
          return;
        }

        this.isInferring = true;
        if (this.currentPixelMap) {
          this.currentPixelMap.release();
        }
        this.currentPixelMap = pixelMap;
        try {
          let inferenceResults = await this.runAiModelInference(pixelMap, energyLevelCallback ,updateBoxesCallback);
          let modelItem = inferenceResults.find(item => item.label === '产品型号');
          let realModel = modelItem ? modelItem.value : '未知型号';
          let defectType = inferenceResults.find(item => item.label === '缺陷类型')?.value;
          let offset = inferenceResults.find(item => item.label === '偏移量')?.value;
          let defectStatus = inferenceResults.find(item => item.label === '缺陷与否')?.value;
          let validationStatus = inferenceResults.find(item => item.label === '校验状态')?.value;
          let isOverallQualified = (defectStatus === '合格') && (validationStatus === '校验合格');
          let newRecord: HistoryItem = {
            productId: 'SN-' + new Date().getTime().toString().slice(-6),
            productModel: realModel,
            isQualified: isOverallQualified,
            energyLevel: currentEnergyLevel, // 结合上面回调拿到的真实能效
            hasDefect: defectStatus !== '合格',
            defectType: defectType || '无',
            offset: offset || '0px',
          };

          animateTo({ duration: 200 }, () => {
            this.results = inferenceResults;

            // 每次推理完成，直接把新数据推入历史记录列表
            this.historyList.unshift(newRecord);

            // 【增加一道保险】：既然是一直获取，为了防止挂机太久把运行内存撑爆，限制最多保留100条记录
            if (this.historyList.length > 100) {
              this.historyList.pop();
            }
          });

        } catch (error) {
          console.error('[AI] 模型推理发生异常: ', error);
        } finally {
          this.isInferring = false;
        }
      } else {
        pixelMap.release();
      }
    });
  }
}

