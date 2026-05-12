import { window } from '@kit.ArkUI';

@Component
export struct Information {
  @Consume('pageStack') pageStack: NavPathStack;
  @State statusBarHeight: number = 0;

  aboutToAppear() {
    window.getLastWindow(getContext(this)).then(win => {
      let avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = px2vp(avoidArea.topRect.height);
    })
  }

  build() {
    NavDestination() {
      Column() {
        // 自定义标题栏 (保持与 History 页面完全一致)
        Row() {
          Image($r('sys.media.ohos_ic_back'))
            .width(28)
            .height(28)
            .fillColor(Color.White)
            .onClick(() => {
              this.pageStack.pop()
            })
          Text('使用指南')
            .fontColor(Color.White)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .margin({ left: 16 })
        }
        .width('100%')
        .padding({ top: this.statusBarHeight + 20, left: 25, bottom: 10 })

        List({ space: 16 }) {
          // --- 模块一：操作流程 ---
          ListItem() {
            this.SectionTitle("操作流程", 'sys.symbol.play_circle_fill')
          }

          ListItem() {
            this.StepItem("01", "对准标签", "点击首页“智能检测”，将相机对准能效标识，建议距离 20cm 左右，确保标识处于屏幕中心。")
          }
          ListItem() {
            this.StepItem("02", "自动分析", "系统将实时进行 OCR 识别与 AI 缺陷检测，请观察实时反馈的识别框颜色。")
          }
          ListItem() {
            this.StepItem("03", "结果归档", "识别成功后，点击“保存”按钮。数据将持久化至您的历史记录中，方便随时查看。")
          }

          // --- 模块二：识别状态说明 (模仿 History 的状态标签风格) ---
          ListItem() {
            this.SectionTitle("状态说明", 'sys.symbol.info_circle_fill')
          }

          ListItem() {
            Row() {
              this.StatusTag("合格", '#28a745')
              Text("标识完整，信息识别一致")
                .fontSize(14)
                .fontColor('#444')
                .margin({ left: 12 })
            }
            .styleCard()
          }

          ListItem() {
            Row() {
              this.StatusTag("不合格", '#dc3545')
              Text("检测到污损、位置偏移或参数异常")
                .fontSize(14)
                .fontColor('#444')
                .margin({ left: 12 })
            }
            .styleCard()
          }

          // --- 模块三：注意事项 ---
          ListItem() {
            Column({ space: 10 }) {
              this.SectionTitle("注意事项", 'sys.symbol.exclamationmark_triangle_fill')
              Text("• 避免强光直射：反光会导致 OCR 识别失败。\n• 完整性检查：确保能效标识的四个角都在画面内。\n• 网络状态：AI 模型在本地运行，无需联网，但同步数据可能需要权限。")
                .fontSize(14)
                .fontColor('#CCFFFFFF')
                .lineHeight(22)
                .padding({ left: 4 })
            }
            .margin({ top: 10, bottom: 40 })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 20, right: 20 })
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Off)
      }
      .linearGradient({
        angle: 135,
        colors: [[0x091E3A, 0.0], [0x2F80ED, 0.5], [0x2D9EE0, 1.0]]
      })
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
  }

  // 模块标题组件
  @Builder
  SectionTitle(title: string, icon: string) {
    Row() {
      SymbolGlyph($r(icon))
        .fontSize(20)
        .fontColor([Color.White])
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ left: 8 })
    }
    .width('100%')
    .margin({ top: 10, bottom: 5 })
  }

  // 步骤组件
  @Builder
  StepItem(num: string, title: string, desc: string) {
    Column() {
      Row() {
        Text(num)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor(0x4361EE)
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .borderRadius(6)
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      Text(desc)
        .fontSize(14)
        .fontColor('#666')
        .margin({ top: 8 })
        .lineHeight(20)
    }
    .styleCard()
  }

  // 状态标签渲染 (复用 History 逻辑)
  @Builder
  StatusTag(text: string, color: string) {
    Text(text)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(color)
      .backgroundColor(color + '1A') // 10% 透明度背景
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .borderRadius(6)
      .border({ width: 1, color: color })
  }

  // 自定义样式属性装饰器（模拟你 History 项目的卡片感）
  @Styles styleCard() {
    .width('100%')
    .padding(16)
    .backgroundColor('rgba(255, 255, 255, 0.75)')
    .borderRadius(12)
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.1)', offsetX: 4, offsetY: 4 })
  }
}