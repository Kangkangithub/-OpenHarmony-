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
export struct History {
  // 模拟历史数据
  @StorageLink('globalHistoryList') historyList: HistoryItem[] = [];
  @Consume('pageStack') pageStack: NavPathStack;
  @State statusBarHeight: number = 0;

  getEnergyColor(level?: number): string {
    switch (level) {
      case 1: return '#12a012'; // 深绿（省电）
      case 2: return '#8bc34a'; // 浅绿
      case 3: return '#ffc107'; // 橙色（高耗能）
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

        List({ space: 20 }) {
          ForEach(this.historyList, (item: HistoryItem) => {
            ListItem() {
              Row() {
                Column(){
                  Text(item.productModel)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                  if (item.energyLevel) {
                    Text(`${item.energyLevel}级能效`)
                      .fontSize(10)
                      .fontColor(Color.White)
                      .backgroundColor(this.getEnergyColor(item.energyLevel))
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .borderRadius(10)
                      .margin({ left: 10 })
                  }
                  Text(`编号:${item.productId}`)
                    .fontSize(14)
                    .fontColor('#666')
                    .margin({top:10})
                  if (!item.isQualified && item.defectType) {
                    Text(`类型: ${item.defectType}`)
                      .fontSize(12)
                      .fontColor('#dc3545') // 红色警示
                      .backgroundColor('#fff1f0')
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .borderRadius(4)
                      .margin({ top: 6 })
                  }
                }
                .alignItems(HorizontalAlign.Start)
                Blank()
                Text(item.isQualified ? '合格' : '不合格')
                  .fontColor(item.isQualified ? '#28a745' : '#dc3545')
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .padding(20)
              .backgroundColor('rgba(255, 255, 255, 0.6)')
              .borderRadius(12)
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
              .onClick(() => {
                this.pageStack.pushPath({ name: 'HistoryDetail', param: item })
              })
            }
          })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, top: 40 })
        .edgeEffect(EdgeEffect.Spring)
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
}