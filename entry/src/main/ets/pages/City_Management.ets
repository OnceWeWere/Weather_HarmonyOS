import dataPreferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import util from '@ohos.util'; // 用于文本解码
import http from '@ohos.net.http'; // 网络请求模块
import { BusinessError } from '@ohos.base'; // 鸿蒙标准错误类型

import { getBackgroundByWeather } from '../utils/updateBackgroundColor';

// 1. 城市卡片
export interface CityCardModel {
  cityName: string;
  CurrentTemperature: string;
  weather: string;
  lowTemp: string;
  highTemp: string;
}

// 城市刷新信息接口
export interface RefreshCityInfo {
  adcode: string;
  cityName: string;
}

// 2. 原始城市数据接口 (对应 JSON 文件)
interface CityInfo {
  cityName: string;
  adcode: string;
}

// 3. 天气 API 接口定义
// 实况天气响应
interface AmapLiveItem {
  province: string;
  city: string;
  adcode: string;
  weather: string;
  temperature: string;
  humidity: string;
  reporttime: string;
}

interface AmapLiveResponse {
  status: string;
  lives: AmapLiveItem[];
}

// 预报天气响应
interface AmapCastItem {
  date: string;
  dayweather: string;
  nightweather: string;
  daytemp: string;
  nighttemp: string;
  week: string;
}

interface AmapForecastItem {
  casts: AmapCastItem[];
}

interface AmapForecastResponse {
  status: string;
  forecasts: AmapForecastItem[];
}

@Preview
@Component
export struct City_Management {
  @Consume('currentLocation') currentLocation: CityCardModel;
  @Consume('refreshCityInfo') refreshCityInfo: RefreshCityInfo = { adcode: '', cityName: '' };
  @Consume('pageStack') pageStack: NavPathStack;
  @Consume('amapKey') amapKey: string;
  // 已添加的城市列表
  @State addedCities: CityCardModel[] = [];
  // 搜索框文字
  @State searchText: string = '';
  // 是否处于搜索模式
  @State isSearchMode: boolean = false;
  // 搜索结果列表
  @State searchResultList: CityInfo[] = [];
  // 全部城市数据 (用于搜索遍历)
  @State allCities: CityInfo[] = [];
  // 核心优化：城市名 -> Adcode 的快速查找表
  private cityMap: Map<string, string> = new Map();
  // 热门城市数据 (这里为了演示方便，手动写死几个，实际也可以从 allCities 筛选)
  private hotCitiesData: string[] = ['北京', '上海', '广州', '深圳', '杭州', '成都'];
  private storeName: string = 'city_management_store';

  aboutToAppear() {
    this.loadCitiesFromLocal(); // 加载用户已保存的城市
    this.loadAllCitiesFromRawFile(); // 加载 RawFile 里的城市字典
  }

  // --- 1. 顶部搜索栏 (Header) ---
  @Builder
  HeaderBar() {
    Row() {
      Search({ placeholder: '请输入城市名', value: this.searchText })
        .id('search_input')
        .height(40)
        // 动画核心：搜索模式下搜索框变短，让出位置给取消按钮
        .layoutWeight(1)
        .backgroundColor(this.isSearchMode ? '#F5F5F5' : 'rgba(0,0,0,0.05)')
        .borderRadius(20)
        .placeholderColor('rgba(0,0,0,0.35)')
        // 获得焦点时，激活搜索模式
        .onFocus(() => {
          if (!this.isSearchMode) {
            animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
              this.isSearchMode = true;
            })
          }
        })
        .onChange((val: string) => {
          this.searchText = val;
          this.handleSearch(val);
        })
        .onSubmit((val: string) => {
          // 回车逻辑：如果有结果，默认添加第一个
          if (this.searchResultList.length > 0) {
            this.addCity(this.searchResultList[0].cityName);
            this.exitSearchMode();
          }
        })

      // 取消按钮：仅在搜索模式显示
      if (this.isSearchMode) {
        Text('取消')
          .fontSize(16)
          .fontColor('#007DFF')
          .margin({ left: 12 })
          // 淡入淡出动画
          .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
          .onClick(() => {
            this.exitSearchMode();
          })
      }
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 5,
      bottom: 5
    })
  }

  // --- 2. 主页面内容 (已添加城市列表) ---
  @Builder
  MainContent() {
    Column() {
      this.SectionTitle('当前位置')

      // 当前位置卡片
      Column() {
        this.CityCard(this.currentLocation ?? {
          cityName: '定位中...',
          CurrentTemperature: '--',
          weather: '获取中',
          lowTemp: '--',
          highTemp: '--',
        }, true)
      }
      .padding({ left: 16, right: 16 })

      if (this.addedCities.length > 0) {
        this.SectionTitle('已添加城市')

        // List 布局优化：占满剩余空间 (layoutWeight)
        List({ space: 0 }) {
          ForEach(this.addedCities, (item: CityCardModel, index: number) => {
            ListItem() {
              // 内容容器：负责左右内缩
              Column() {
                this.CityCard(item, false)
              }
              .width('100%')
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                // 点击卡片，切换到该城市
                const adcode = this.getAdcodeByName(item.cityName);
                if (adcode) {
                  const formattedName = this.formatCityName(item.cityName);
                  console.info('Debug: [城市切换] 点击城市=' + formattedName + ', adcode=' + adcode);
                  // 先设置刷新标记（使用对象传递，更可靠）
                  this.refreshCityInfo = { adcode: adcode, cityName: formattedName };
                  // 更新当前位置（显示名也补“市”）
                  this.currentLocation = {
                    cityName: formattedName,
                    CurrentTemperature: item.CurrentTemperature,
                    weather: item.weather,
                    lowTemp: item.lowTemp,
                    highTemp: item.highTemp,
                  };
                  // 延迟返回，确保状态更新完成
                  setTimeout(() => {
                    try {
                      console.info('Debug: [城市切换] 准备返回主页，refreshCityInfo=' + JSON.stringify(this.refreshCityInfo));
                      this.pageStack.pop();
                    } catch (e) {
                      console.error('Debug: 返回主页失败', JSON.stringify(e));
                    }
                  }, 200);
                } else {
                  console.error('Debug: [城市切换] 无法找到城市 adcode: ' + item.cityName);
                }
              })
            }
            // 关键：Margin 给 ListItem，保证侧滑按钮高度与卡片一致
            .margin({ bottom: 14 })
            .swipeAction({
              end: () => this.DeleteAction(index)
            })
          })
        }
        .layoutWeight(1) // 解决“滚不到底”的问题
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      } else {
        // 空占位，防止 Flex 布局塌陷
        Column().layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
  }

  // --- 3. 搜索页面内容 ---
  @Builder
  SearchContent() {
    List() {
      // 场景 A: 未输入文字 -> 显示热门城市
      if (this.searchText.trim().length === 0) {
        ListItem() {
          Text('热门城市')
            .fontSize(14)
            .fontColor('#999')
            .margin({ top: 20, bottom: 10 })
        }

        ListItem() {
          Grid() {
            ForEach(this.hotCitiesData, (name: string) => {
              GridItem() {
                Text(name)
                  .padding({
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: 8
                  })
                  .backgroundColor('#F0F0F0')
                  .borderRadius(16)
                  .fontSize(14)
                  .fontColor('#333')
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    this.addCity(name);
                    this.exitSearchMode();
                  })
              }
            })
          }
          .columnsTemplate('1fr 1fr 1fr')
          .rowsGap(12)
          .columnsGap(12)
          .width('100%')
          .margin({ top: 10, bottom: 10 })
        }
      }
      // 场景 B: 有输入 -> 显示搜索结果
      else {
        if (this.searchResultList.length === 0) {
          ListItem() {
            Column() {
              Text('未找到相关城市').fontColor('#999').margin({ top: 40 })
            }
            .width('100%').alignItems(HorizontalAlign.Center)
          }
        } else {
          ForEach(this.searchResultList, (city: CityInfo) => {
            ListItem() {
              Row() {
                // 简单的匹配高亮逻辑可以在这里扩展
                Text(city.cityName).fontSize(16).fontColor('#333')
              }
              .width('100%')
              .height(50)
              .alignItems(VerticalAlign.Center)
              .border({ width: { bottom: 0.5 }, color: '#EEE' })
              .onClick(() => {
                this.addCity(city.cityName);
                this.exitSearchMode();
              })
            }
          })
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
    .scrollBar(BarState.Off)
    // 搜索页从底部升起的过渡动画
    .transition(TransitionEffect.move(TransitionEdge.BOTTOM).animation({ duration: 250 }))
  }

  build() {
    NavDestination() {
      Column() {
        // 1. 顶部栏 (常驻)
        this.HeaderBar()

        // 2. 内容区 (根据状态切换)
        Column() {
          if (this.isSearchMode) {
            this.SearchContent()
          } else {
            this.MainContent()
          }
        }
        .layoutWeight(1)
        .width('100%')

        // 隐藏的焦点接收组件，用于取消搜索框焦点
        Button()
          .id('dummy_focus')
          .width(0)
          .height(0)
          .opacity(0)
          .focusable(true)
      }
      .width('100%')
      .height('100%')
    }
    .height('100%')
    .width('100%')
    .title(this.isSearchMode ? '' : this.CustomTitle())
    .backgroundColor('#F7F8FA')
  }

  // --- 4. 逻辑处理方法 ---

  // 核心：读取 RawFile 中的 JSON 并构建 Map
  private async loadAllCitiesFromRawFile() {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const resourceManager = context.resourceManager;

      const fileData = await resourceManager.getRawFileContent('city_code.json');
      const textDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const text = textDecoder.decodeWithStream(fileData, { stream: false });

      const list = JSON.parse(text) as CityInfo[];
      this.allCities = list;

      // 构建 Map：O(1) 复杂度查找
      list.forEach(item => {
        this.cityMap.set(item.cityName, item.adcode);
      });

      console.info('Debug: 城市数据加载完成，MapSize=' + this.cityMap.size);
    } catch (e) {
      console.error('Debug: 加载城市数据失败', JSON.stringify(e));
    }
  }

  // 辅助方法：对外提供查 Adcode 的能力
  // 当你需要请求天气 API 时，调用此方法： this.getAdcodeByName('北京市') -> 返回 '110000'
  private getAdcodeByName(name: string): string {
    return this.cityMap.get(name) ?? '';
  }

  // 城市名称展示：长度<3且未包含“市”则补“市”
  private formatCityName(name: string): string {
    const trimmed = (name ?? '').trim();
    if (!trimmed) {
      return '';
    }
    if (trimmed.endsWith('市')) {
      return trimmed;
    }
    return trimmed.length < 3 ? `${trimmed}市` : trimmed;
  }

  // 搜索过滤逻辑
  private handleSearch(keyword: string) {
    if (!keyword || keyword.trim() === '') {
      this.searchResultList = [];
      return;
    }
    this.searchResultList = this.allCities.filter(city =>
    city.cityName.includes(keyword)
    );
  }

  // 添加城市并获取天气数据
  private async addCity(name: string) {
    const trimmed = (name ?? '').trim();
    if (!trimmed) {
      return;
    }

    const exist = this.addedCities.find(c => c.cityName === trimmed);
    if (exist) {
      return;
    }

    // 先创建一个临时卡片，显示加载状态
    const loadingCard: CityCardModel = {
      cityName: trimmed,
      CurrentTemperature: '--',
      weather: '获取中',
      lowTemp: '--',
      highTemp: '--',
    };

    this.addedCities = [...this.addedCities, loadingCard];
    this.searchText = '';
    await this.saveCitiesToLocal();

    // 获取 adcode 并请求天气数据
    const adcode = this.getAdcodeByName(trimmed);
    if (adcode) {
      await this.fetchWeatherForCity(trimmed, adcode);
    } else {
      // 如果找不到 adcode，使用默认数据
      const defaultCard: CityCardModel = {
        cityName: trimmed,
        CurrentTemperature: '--',
        weather: '未知',
        lowTemp: '--',
        highTemp: '--',
      };
      const index = this.addedCities.findIndex(c => c.cityName === trimmed);
      if (index >= 0) {
        const updated = [...this.addedCities];
        updated[index] = defaultCard;
        this.addedCities = updated;
        await this.saveCitiesToLocal();
      }
    }

    // 添加城市后，确保取消焦点
    setTimeout(() => {
      try {
        focusControl.requestFocus('dummy_focus')
      } catch (e) {
        // 如果焦点转移失败，忽略错误
      }
    }, 100)
  }

  // 获取城市天气数据
  private async fetchWeatherForCity(cityName: string, adcode: string) {
    try {
      // 请求预报天气（包含当天数据）
      const forecastUrl = `https://restapi.amap.com/v3/weather/weatherInfo?city=${adcode}&key=${this.amapKey}&extensions=all`;
      const reqForecast = http.createHttp();

      reqForecast.request(forecastUrl, {
        method: http.RequestMethod.GET,
        connectTimeout: 3000,
        readTimeout: 3000
      }, (err: Error, data: http.HttpResponse) => {
        if (err || !data.result) {
          console.error('Debug: [城市天气] 请求失败', JSON.stringify(err));
          this.updateCityCardWithDefault(cityName);
          return;
        }

        try {
          const res = JSON.parse(data.result.toString()) as AmapForecastResponse;
          if (res.status === '1' && res.forecasts.length > 0) {
            const casts = res.forecasts[0].casts;
            if (casts.length > 0) {
              // 获取当天数据（第一个元素）
              const today = casts[0];
              
              // 同时请求实况天气获取当前温度
              const liveUrl = `https://restapi.amap.com/v3/weather/weatherInfo?city=${adcode}&key=${this.amapKey}&extensions=base`;
              const reqLive = http.createHttp();

              reqLive.request(liveUrl, {
                method: http.RequestMethod.GET,
                connectTimeout: 3000,
                readTimeout: 3000
              }, (errLive: Error, dataLive: http.HttpResponse) => {
                let currentTemp = today.daytemp; // 默认使用白天温度
                
                if (!errLive && dataLive.result) {
                  try {
                    const resLive = JSON.parse(dataLive.result.toString()) as AmapLiveResponse;
                    if (resLive.status === '1' && resLive.lives.length > 0) {
                      currentTemp = resLive.lives[0].temperature;
                    }
                  } catch (e) {
                    console.error('Debug: [城市天气] 实况解析失败');
                  }
                }

                // 更新城市卡片
                const updatedCard: CityCardModel = {
                  cityName: cityName,
                  CurrentTemperature: currentTemp,
                  weather: today.dayweather,
                  lowTemp: today.nighttemp,
                  highTemp: today.daytemp,
                };

                const index = this.addedCities.findIndex(c => c.cityName === cityName);
                if (index >= 0) {
                  const updated = [...this.addedCities];
                  updated[index] = updatedCard;
                  this.addedCities = updated;
                  this.saveCitiesToLocal();
                }
              });
            } else {
              this.updateCityCardWithDefault(cityName);
            }
          } else {
            this.updateCityCardWithDefault(cityName);
          }
        } catch (e) {
          console.error('Debug: [城市天气] 解析失败', JSON.stringify(e));
          this.updateCityCardWithDefault(cityName);
        }
      });
    } catch (e) {
      console.error('Debug: [城市天气] 请求异常', JSON.stringify(e));
      this.updateCityCardWithDefault(cityName);
    }
  }

  // 更新城市卡片为默认数据
  private async updateCityCardWithDefault(cityName: string) {
    const defaultCard: CityCardModel = {
      cityName: cityName,
      CurrentTemperature: '--',
      weather: '获取失败',
      lowTemp: '--',
      highTemp: '--',
    };
    const index = this.addedCities.findIndex(c => c.cityName === cityName);
    if (index >= 0) {
      const updated = [...this.addedCities];
      updated[index] = defaultCard;
      this.addedCities = updated;
      await this.saveCitiesToLocal();
    }
  }

  private exitSearchMode() {
    // 先取消搜索框焦点，收起键盘
    // 使用延迟确保焦点转移成功，在下一帧执行
    setTimeout(() => {
      try {
        focusControl.requestFocus('dummy_focus')
      } catch (e) {
        // 如果焦点转移失败，忽略错误
      }
    }, 50)
    // 更新状态
    this.searchText = ''
    animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
      this.isSearchMode = false
    })
  }

  private async deleteCityAt(index: number) {
    if (index < 0 || index >= this.addedCities.length) {
      return;
    }
    const next = [...this.addedCities];
    next.splice(index, 1);
    this.addedCities = next;
    await this.saveCitiesToLocal();
  }

  // --- 5. 持久化存储 ---
  private async loadCitiesFromLocal() {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const pref = await dataPreferences.getPreferences(ctx, this.storeName);
      const raw = pref.getSync('addedCities', '[]') as string;
      const parsed = JSON.parse(raw) as CityCardModel[];
      if (this.addedCities.length === 0 && parsed && parsed.length >= 0) {
        this.addedCities = parsed;
      }
    } catch (e) {
    }
  }

  private async saveCitiesToLocal() {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const pref = await dataPreferences.getPreferences(ctx, this.storeName);
      pref.putSync('addedCities', JSON.stringify(this.addedCities));
      await pref.flush();
    } catch (e) {
    }
  }

  // --- 6. 纯样式组件 ---
  @Builder
  CustomTitle() {
    Row() {
      Text('城市管理')
        .width('100%')
        .fontSize(22)
        .textAlign(TextAlign.End)
        .padding({ right: 25 })
        .fontWeight(FontWeight.Medium)
    }
    .height('100%')
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .width('100%')
      .fontSize(14)
      .fontColor('rgba(0,0,0,0.35)')
      .padding({ left: 34, bottom: 10, top: 10 })
      .fontWeight(FontWeight.Medium)
  }

  @Builder
  CityCard(data: CityCardModel, isCurrent: boolean = false) {
    Column() {
      Row() {
        Column({ space: 4 }) {
          Row() {
            Text(this.formatCityName(data.cityName)).fontSize(18).fontColor(Color.White).fontWeight(FontWeight.Bold)
            if (isCurrent) {
              SymbolGlyph($r('sys.symbol.local_fill')).fontSize(16).fontColor([Color.White]).margin({ left: 4 })
            }
          }

          Text(data.weather).fontSize(14).fontColor('rgba(255,255,255,0.85)').fontWeight(FontWeight.Medium)
        }
        .alignItems(HorizontalAlign.Start).layoutWeight(1)

        Column({ space: 2 }) {
          Text(data.CurrentTemperature + '°').fontSize(32).fontColor(Color.White).textAlign(TextAlign.End)
          Text(`${data.highTemp}° / ${data.lowTemp}°`)
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.85)')
            .textAlign(TextAlign.End)
        }
        .alignItems(HorizontalAlign.End)
      }
    }
    .padding({
      left: 18,
      right: 18,
      top: 16,
      bottom: 14
    })
    .borderRadius(16)
    .linearGradient({ angle: 180, colors: getBackgroundByWeather(data.weather) })
    .shadow({ radius: 12, color: 'rgba(0,0,0,0.08)', offsetY: 4 })
  }

  @Builder
  DeleteAction(index: number) {
    Column() {
      SymbolGlyph($r('sys.symbol.trash')).fontSize(22).fontColor([Color.White]).margin({ bottom: 4 })
    }
    .margin({ right: 15 })
    .borderRadius('50%')
    .width(60)
    .height(60)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#E54D42')
    .onClick(() => this.deleteCityAt(index))
  }
}


