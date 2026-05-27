// 在文件顶部声明类型（参考 Index.ets 的写法）
interface NewsItem {
  id: number;
  title: string;
  summary: string;
  source: string;
  time: string;
  category: string;
}

@Preview
@Component
export struct News {
  @Consume('pageStack') pageStack: NavPathStack;

  // 新闻数据（使用顶层接口声明类型）
  @State newsList: NewsItem[] = [
    {
      id: 1,
      title: '全国多地迎来降雨降温 气象专家提醒注意保暖',
      summary: '中央气象台预计，未来三天我国中东部地区将迎来一轮降雨过程，降温幅度可达4-8℃。气象专家提醒公众及时增添衣物，预防感冒。',
      source: '中国天气网',
      time: '2024-12-30 14:30',
      category: '天气'
    },
    {
      id: 2,
      title: '人工智能天气预报准确率突破95% 引领气象新纪元',
      summary: '最新研究显示，基于深度学习的AI天气预报模型已在多个地区投入使用，准确率相比传统方法提升了15个百分点。',
      source: '科技日报',
      time: '2024-12-30 12:15',
      category: '科技'
    },
    {
      id: 3,
      title: '全球气候变化影响加剧 南极冰川融化速度加快',
      summary: '科学家最新研究发现，南极洲部分冰川的融化速度比预期加快了30%，这将对全球海平面产生重要影响。',
      source: '新华网',
      time: '2024-12-30 10:45',
      category: '环境'
    },
    {
      id: 4,
      title: '冬日养生指南：合理饮食增强免疫力',
      summary: '冬季气温降低，人体免疫力相对较弱。营养专家建议多食用富含维生素C的食物，如新鲜蔬菜水果，同时保证充足睡眠。',
      source: '健康时报',
      time: '2024-12-30 09:20',
      category: '健康'
    },
    {
      id: 5,
      title: '新能源汽车市场蓬勃发展 充电设施建设加速',
      summary: '随着新能源汽车销量的持续增长，全国充电桩数量已突破500万个，基本满足用户出行需求。',
      source: '经济日报',
      time: '2024-12-30 08:10',
      category: '经济'
    }
  ];

  // 根据分类获取颜色（使用 switch-case，避免索引签名与对象字面量作为类型）
  private getCategoryColor(category: string): string {
    switch (category) {
      case '天气':
        return '#4A90E2';
      case '科技':
        return '#50C878';
      case '环境':
        return '#32CD32';
      case '健康':
        return '#FF6B6B';
      case '经济':
        return '#FFA500';
      default:
        return '#9B59B6';
    }
  }

  @Builder
  NewsCard(item: NewsItem) {
    Column() {
      // 标题和分类标签
      Row() {
        // 新闻标题
        Text(item.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        // 分类标签
        Text(item.category)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor(this.getCategoryColor(item.category))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(12)
          .margin({ left: 12 })
      }
      .width('100%')
      // .alignItems(VerticalAlign.Start)
      .margin({ bottom: 12 })

      // 新闻摘要
      Text(item.summary)
        .fontSize(14)
        .fontColor('#666666')
        .lineHeight(20)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ bottom: 12 })

      // 底部信息栏
      Row() {
        // 来源
        Text(item.source)
          .fontSize(12)
          .fontColor('#999999')

        // 分隔符
        Text(' · ')
          .fontSize(12)
          .fontColor('#CCCCCC')

        // 时间
        Text(item.time)
          .fontSize(12)
          .fontColor('#999999')

        Blank()
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.08)', offsetY: 2 })
  }

  build() {
    NavDestination() {
      if (this.newsList && this.newsList.length > 0) {
        List({ space: 12 }) {
          ForEach(this.newsList, (item: NewsItem, index: number) => {
            ListItem() {
              Column() {
                this.NewsCard(item)
              }
              .width('100%')
              .padding({ left: 16, right: 16 })
            }
          }, (item: NewsItem) => item.id.toString())
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .backgroundColor('#F5F5F5')
      } else {
        Column() {
          Text('暂无更多新闻')
            .fontSize(16)
            .fontColor('#999999')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F5F5F5')
      }
    }
    .title('新闻')
    .backgroundColor('#F5F5F5')
  }
}

