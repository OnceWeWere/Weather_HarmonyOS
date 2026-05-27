@Preview
@Component
export struct User {
  @Consume('pageStack') pageStack: NavPathStack;

  // 用户信息状态
  @State userAvatar: Resource = $r('app.media.default_avatar'); // 头像资源
  @State userName: string = 'Root';
  @State userSignature: string = '花开花落终有时 相逢相聚本无意';


  @Builder
  CustomTitle() {
    Row() {
      Text('我的')
        .width('100%')
        .fontSize(22)
        .textAlign(TextAlign.End)
        .padding({ right: 25 })
        .fontWeight(FontWeight.Medium)
    }
    .height('100%')
  }

  @Builder
  UserInfoSection() {
    Column() {
      // 用户头像和基本信息
      Row() {
        // 头像
        Column() {
          Image(this.userAvatar)
            .width(80)
            .height(80)
            .borderRadius(40)
            .margin({ right: 16 })
            .onClick(() => {
              // TODO: 点击更换头像
            })
        }

        // 用户信息
        Column({ space: 8 }) {
          Text(this.userName)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')

          Text(this.userSignature)
            .fontSize(14)
            .fontColor('#666')

          // 编辑按钮
          Text('编辑资料')
            .fontSize(14)
            .fontColor('#007AFF')
            .margin({ top: 4 })
            .onClick(() => {
              // TODO: 跳转到编辑资料页面
            })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .padding({
        left: 20,
        right: 20,
        top: 20,
        bottom: 20
      })
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({  top: 16 })
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.08)', offsetY: 2 })
  }

  @Builder
  MenuItem(icon: Resource, title: string, subtitle: string = '', showArrow: boolean = true) {
    Row() {
      // 图标
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor(['#666'])
        .margin({ right: 12 })

      // 文字内容
      Column({ space: 2 }) {
        Text(title)
          .fontSize(16)
          .fontColor('#333')

        if (subtitle.length > 0) {
          Text(subtitle)
            .fontSize(12)
            .fontColor('#999')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 箭头
      if (showArrow) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor(['#CCC'])
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)

    .borderRadius(8)
    .onClick(() => {
      // 处理点击事件
      this.handleMenuClick(title);
    })
  }

  @Builder
  MenuSection() {
    Column({ space: 10 }) {
      this.MenuItem($r('sys.symbol.gearshape'), '设置', '应用偏好设置')
      this.MenuItem($r('sys.symbol.local_fill'), '位置服务', '管理定位权限')
      this.MenuItem($r('sys.symbol.bell_fill'), '通知设置', '天气提醒配置')
      this.MenuItem($r('sys.symbol.star'), '收藏城市', '管理收藏的城市')
      this.MenuItem($r('sys.symbol.heart'), '反馈与建议', '帮助我们改进')
    }
    .width('100%')
    .borderRadius(12)
    .background(Color.White)
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.08)', offsetY: 2 })
  }


  // 处理菜单点击事件
  private handleMenuClick(title: string) {
    switch (title) {
      case '设置':
        // TODO: 跳转到设置页面
        break;
      case '位置服务':
        // TODO: 跳转到位置服务设置
        break;
      case '通知设置':
        // TODO: 跳转到通知设置
        break;
      case '收藏城市':
        this.pageStack.pushPath({ name: 'City_Management' });
        break;
      case '反馈与建议':
        // TODO: 跳转到反馈页面
        break;
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          // 用户信息区域
          this.UserInfoSection()

          // 中间空白区域
          Blank().height(20)

          // 菜单选项区域
          this.MenuSection()


        }
        .height('100%')
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({left:16,right:16})
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .title(this.CustomTitle())
    .backgroundColor('#F7F8FA')
  }
}

