import { window } from '@kit.ArkUI';

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

@Component
export struct HistoryDetail {
  @Consume('pageStack') pageStack: NavPathStack = new NavPathStack();
  // 获取传递过来的参数
  @State data: HistoryItem = (this.pageStack.getParamByName('HistoryDetail')[0] as HistoryItem);
  @State statusBarHeight: number = 0;

  getEnergyColor(level?: number): string {
    switch (level) {
      case 1: return '#12a012';
      case 2: return '#8bc34a';
      case 3: return '#ffc107';
      default: return '#999';
    }
  }

  aboutToAppear() {
    window.getLastWindow(getContext(this)).then(win => {
      // 获取系统规避区域（状态栏）
      let avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      // 关键：将 px 转换为 vp 才能直接用于组件属性
      this.statusBarHeight = px2vp(avoidArea.topRect.height);
      console.info('状态栏高度已获取: ' + this.statusBarHeight);
    })
  }

  build() {
    NavDestination() {
      Column() {
        Row(){
          Image($r('sys.media.ohos_ic_back'))
            .width(28)
            .height(28)
            .fillColor(Color.White)
            .onClick(()=>{
              this.pageStack.pop()
            })
          Text('历史记录')
            .fontColor(Color.White)
            .fontSize(20)
            .margin({left:16})
        }
        .width('100%')
        .padding({ top: this.statusBarHeight + 20, left: 25 })
        List() {
          // --- 基础信息（始终展示） ---
          this.DetailItem('产品型号', this.data.productModel)
          this.DetailItem('产品编号', this.data.productId)
          this.DetailItem('检测结果', this.data.isQualified ? '合格' : '不合格', this.data.isQualified ? Color.Green : Color.Red)

          if (this.data.energyLevel) {
            ListItem() {
              Row() {
                Text('能效等级').fontSize(16).fontColor('#666')
                Blank()
                Text(`${this.data.energyLevel}级`)
                  .fontSize(14)
                  .fontColor(Color.White)
                  .backgroundColor(this.getEnergyColor(this.data.energyLevel))
                  .padding({ left: 10, right: 10, top: 2, bottom: 2 })
                  .borderRadius(10)
              }.width('100%').padding(16)
            }
          }

          // --- 动态展示：能效标签（如果有则展示） ---
          if (this.data.energyLabel) {
            ListItem() {
              Row() {
                Text('能效标签').fontSize(16)
                Blank()
                Image(this.data.energyLabel).width(60).height(30)
              }.width('100%').padding(16)
            }
          }

          // --- 核心逻辑：如果不合格，展示额外数据 ---
          if (!this.data.isQualified) {
            this.DetailItem('是否存在缺陷', this.data.hasDefect ? '是' : '否')
            if (this.data.hasDefect && this.data.defectType) {
              this.DetailItem('缺陷类型', this.data.defectType, Color.Red)
            }
            this.DetailItem('位置偏移量', this.data.offset || '无')
          }
        }
        .backgroundColor(Color.White)
        .divider({ strokeWidth: 1, color: '#f0f0f0', startMargin: 16, endMargin: 16 })
        .borderRadius(12)
        .margin({top:40 , left:16 , right:16 , bottom:16})
      }
      .linearGradient({
        angle:135,
        colors:[[0x091E3A, 0.0], [0x2F80ED, 0.5], [0x2D9EE0, 1.0]]
      })
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
  }

  // 自定义通用的详情行组件
  @Builder DetailItem(label: string, value: string, valueColor: ResourceColor = '#333') {
    ListItem() {
      Row() {
        Text(label).fontSize(16).fontColor('#666')
        Blank()
        Text(value).fontSize(16).fontColor(valueColor).fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .padding(16)
    }
  }
}