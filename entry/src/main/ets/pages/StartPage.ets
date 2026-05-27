// 方案	        独立页面法 (推荐新手)	                                       主页遮罩法 (进阶)
// 文件结构	      新建 SplashPage.ets	                                       就在 Index.ets 里写
// 原理	          启动先看广告页 -> 销毁 -> 跳转主页	                           主页内容上层盖一个广告层 -> 隐藏广告层
// 优点	          逻辑解耦，代码干净，易维护	视觉体感更快，广告结束时主页内容已加载好
// 缺点	          跳转主页时可能有一瞬白屏或加载感	                                主页代码逻辑会变得复杂耦合
import { font } from '@kit.ArkUI';
import { text } from '@kit.ArkGraphics2D'


@Entry
@Component
struct StartIndex {
  @State timeOut_StatPage: number = 0;
  @State pageScale: number = 1; // 默认大小 1倍
  @State pageOpacity: number = 1; // 默认不透明

  aboutToAppear(): void {
    // 注册字体
    font.registerFont({
      familyName: '阿朱泡泡体',
      familySrc: $rawfile('fonts/阿朱泡泡体.ttf')
    })

    this.timeOut_StatPage = setTimeout(() => {
      this.startExitAnimation()
    }, 2000)
  }

  // 良好的编程习惯：页面即将销毁（兜底保险）
  aboutToDisappear(): void {
    clearTimeout(this.timeOut_StatPage)
  }

  private toIndex() {
    // 主动清理
    clearTimeout(this.timeOut_StatPage)
    this.getUIContext().getRouter().replaceUrl({ url: "pages/Index" }).catch(() => {
    })
  }

  // 自定义退出动画逻辑
  private startExitAnimation() {
    this.getUIContext().animateTo({
      duration: 800, curve: Curve.EaseOut, onFinish: () => {
        this.toIndex()
      }
    }, () => {
      this.pageScale = 1.3; // 放大到 1.5 倍
      this.pageOpacity = 0; // 变全透明
    })
  }

  build() {
    Column() {
      Image($r('app.media.weather_icon'))
        .width(150)
        .height(150)
        .opacity(this.pageOpacity) // 绑定透明度
        .scale({ x: this.pageScale, y: this.pageScale }) // 绑定缩放

      Blank().layoutWeight(1)

      Column({ space: 10 }) {
        Text('高仿小米天气')
          .fontColor('#929292')
          .fontFamily('阿朱泡泡体')

        Text('Powered by ZSC & Gemini3 Pro')
          .fontColor('#929292')
          .fontFamily('阿朱泡泡体')
      }
      .opacity(this.pageOpacity) // 绑定透明度

    }
    .height('100%')
    .width('100%')
    .padding({ top: 70 })


    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  // 页面间转场：https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-page-transition-animation#pagetransitionenter
  // pageTransition() {
  //
  // }
}