import {Test} from './Test';
import {History} from './History';
import {Information} from './Information';
import { HistoryDetail } from './HistoryDetail';

@Builder
// 定义路由栈
function PageMap(name:string){
  if(name === 'Test'){
    Test()
  }else if(name === 'History'){
    History()
  }else if(name === 'Information'){
    Information()
  }else if(name === 'HistoryDetail'){
    HistoryDetail()
  }
}

@Entry
@Component
struct Index {
  @Provide('pageStack') pageStack:NavPathStack = new NavPathStack()
  @State message: string = 'Hello World';

  build() {
    Navigation(this.pageStack){
      Column({space:50}) {
        Image($r('app.media.logo1'))
          .width(160)               // 缩小宽度
          .height(60)               // 限制高度，避免占用过多纵向空间
          .objectFit(ImageFit.Contain)
          .margin({
            top: -20,               // 向上微调，抵消部分空白高度
            bottom: -30             // 关键点：通过负 margin 减少 Logo 占用的占位空间，
            // 从而让标题“鸿眸能效...”维持在原来的视觉高度
          })

        Text("鸿眸能效标签检测系统")
          .fontColor(Color.White)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .padding({
            bottom: 50
          })
        Button(){
          Column(){
            SymbolGlyph($r('sys.symbol.camera'))
              .fontSize(56)
              .fontColor([Color.White])
            Text("智能检测")
              .fontSize(36)
              .fontColor(Color.White)
          }
        }
          .width(250)
          .height(130)
          .backgroundColor(0x06D6A0)
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
            this.pageStack.pushPath({name : 'Test'})
          })
        Button(){
          Column(){
            SymbolGlyph($r('sys.symbol.clock'))
              .fontSize(56)
              .fontColor([Color.White])
            Text("历史记录")
              .fontSize(36)
              .fontColor(Color.White)
          }
        }
          .width(250)
          .height(130)
          .backgroundColor(0x4361EE)
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
            this.pageStack.pushPath({name : 'History'})
          })
        Button(){
          Column(){
            SymbolGlyph($r('sys.symbol.folder_badge_eye'))
              .fontSize(56)
              .fontColor([Color.White])
            Text("使用说明")
              .fontSize(36)
              .fontColor(Color.White)
          }
        }
          .width(250)
          .height(130)
          .backgroundColor(0x8D99AE)
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
            bottom:20
          })
          .onClick(() => {
            this.pageStack.pushPath({name : 'Information'})
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .linearGradient({
      angle:135,
      colors:[[0x091E3A, 0.0], [0x2F80ED, 0.5], [0x2D9EE0, 1.0]]
    })
    .navDestination(PageMap)
    .mode(NavigationMode.Stack)
    .titleMode(NavigationTitleMode.Free)
    .hideTitleBar(true)
    }
}