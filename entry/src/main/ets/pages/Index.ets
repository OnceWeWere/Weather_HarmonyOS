import http from '@ohos.net.http'; // 网络请求模块
import common from '@ohos.app.ability.common'; // 上下文模块（用于跳转设置）
import connection from '@ohos.net.connection'; // 网络连接状态检查模块
import Want from '@ohos.app.ability.Want'; // 意图模块（用于描述跳转目标）
import { BusinessError } from '@ohos.base'; // 鸿蒙标准错误类型

import { City_Management, CityCardModel } from './City_Management';
import { News } from './News';
import { User } from './User';
import { getBackgroundByWeather } from '../utils/updateBackgroundColor';


// 1. 设置 API Key
const AMAP_KEY = "b052eaa050292e6d8b500a37506e594e";

// ==========================================
// 1. 接口定义
// ==========================================

interface WeatherModel {
  date: string;
  dayWeather: string;
  nightWeather: string;
  dayTemp: string;
  nightTemp: string;
  weekStr: string;
}

interface AmapLiveItem {
  province: string;
  city: string;
  adcode: string;
  weather: string;
  temperature: string;
  humidity: string
  reporttime: string;
}

interface AmapLiveResponse {
  status: string;
  lives: AmapLiveItem[];
}

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

interface AmapIpResponse {
  status: string;
  province: string;
  city: string;
  adcode: string;
  rectangle: string;
  infocode?: string;
  info?: string;
}

interface RefreshCityInfo {
  adcode: string;
  cityName: string;
}

// ==========================================
// 2. 主页面组件
// ==========================================

@Entry
@Component
struct WeatherApp {
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack();
  @Provide('currentLocation') currentLocation: CityCardModel = {
    cityName: '定位中...',
    CurrentTemperature: '--',
    weather: '获取中',
    lowTemp: '--',
    highTemp: '--'
  };
  @Provide('refreshCityInfo') @Watch('onRefreshCityInfoChanged') refreshCityInfo: RefreshCityInfo =
    { adcode: '', cityName: '' };
  @Provide('amapKey') amapKey: string = AMAP_KEY;
  // --- 状态变量 ---
  @State cityName: string = "定位中...";
  @State currentTemp: string = "--";
  @State WeatherConditions: string = "晴";
  @State lowTemp: string = "0";
  @State highTemp: string = "0";
  @State aqiLevel: string = "良";
  @State aqiValue: string = "--";
  @State forecasts: WeatherModel[] = [];
  // --- 控制变量 ---
  @State isRefreshing: boolean = false;
  @State isNetworkError: boolean = false;
  @State isSwitchingCity: boolean = false;
  @State showMenu: boolean = false; // 控制弹窗显示
  // --- 动画相关变量 ---
  @State updateTips: string = "";
  @State showUpdateTips: boolean = false;
  @State updateTipsHeight: number = 0;
  @State updateTipsOpacity: number = 0;
  @State isUpdateComplete: boolean = false;
  @State bgColors: [string, number][] = [['#2980B9', 0.0], ['#6DD5FA', 1.0]];

  // 1. 页面初始化生命周期
  aboutToAppear() {
    console.info("Debug: 应用启动 (aboutToAppear)");
    this.checkNetworkAndLocate();
  }

  // 监听城市刷新信息变化
  onRefreshCityInfoChanged() {
    setTimeout(() => {
      if (this.refreshCityInfo && this.refreshCityInfo.adcode && this.refreshCityInfo.adcode !== '') {
        console.info("Debug: [@Watch] 检测到城市切换");
        const adcode = this.refreshCityInfo.adcode;
        const cityName = this.refreshCityInfo.cityName;
        this.isSwitchingCity = true;
        this.refreshCityInfo = { adcode: '', cityName: '' };
        this.cityName = cityName;
        this.isNetworkError = false;
        this.isRefreshing = true;
        this.showUpdateTips = true;
        this.isUpdateComplete = false;
        this.updateTips = "正在更新...";
        this.getUIContext().animateTo({ duration: 300 }, () => {
          this.updateTipsHeight = 30;
          this.updateTipsOpacity = 1;
        });
        this.getWeatherDetails(adcode);
      }
    }, 50);
  }

  // 2. 页面显示生命周期
  onPageShow() {
    setTimeout(() => {
      if (this.isSwitchingCity) {
        return;
      }
      if (this.refreshCityInfo && this.refreshCityInfo.adcode && this.refreshCityInfo.adcode !== '') {
        const adcode = this.refreshCityInfo.adcode;
        const cityName = this.refreshCityInfo.cityName;
        this.isSwitchingCity = true;
        this.refreshCityInfo = { adcode: '', cityName: '' };
        this.cityName = cityName;
        this.isNetworkError = false;
        this.isRefreshing = true;
        this.showUpdateTips = true;
        this.isUpdateComplete = false;
        this.updateTips = "正在更新...";
        this.getUIContext().animateTo({ duration: 300 }, () => {
          this.updateTipsHeight = 30;
          this.updateTipsOpacity = 1;
        });
        this.getWeatherDetails(adcode);
        return;
      }
      if (!this.isSwitchingCity && (this.cityName === "无法获取" || this.cityName === "定位中...")) {
        this.checkNetworkAndLocate();
      }
    }, 100);
  }

  // --- 检查网络状态并定位 ---
  checkNetworkAndLocate() {
    this.cityName = "定位中...";
    this.isNetworkError = false;
    connection.hasDefaultNet().then((hasNet: boolean) => {
      if (hasNet) {
        this.getLocationByIP();
      } else {
        setTimeout(() => {
          this.setLocateError();
        }, 3000);
      }
    }).catch((err: BusinessError) => {
      this.getLocationByIP();
    });
  }

  // --- 设置定位错误 ---
  setLocateError() {
    this.isNetworkError = true;
    this.cityName = "无法获取";
    this.currentTemp = "--";
    this.forecasts = [];
    this.updateCurrentLocationFromState();
    setTimeout(() => {
      this.isRefreshing = false;
      this.hideUpdateTips();
    }, 1000);
  }

  // --- 辅助函数：收起顶部更新提示 ---
  hideUpdateTips() {
    if (this.showUpdateTips) {
      this.getUIContext().animateTo({ duration: 300 }, () => {
        this.updateTipsHeight = 0;
        this.updateTipsOpacity = 0;
      });
      setTimeout(() => {
        this.showUpdateTips = false;
      }, 300);
    }
  }

  // --- 核心功能：IP 定位 ---
  getLocationByIP() {
    let url = `https://restapi.amap.com/v3/ip?key=${AMAP_KEY}`;
    let req = http.createHttp();

    req.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 3000,
      readTimeout: 3000
    }, (err: Error, data: http.HttpResponse) => {
      if (err || data.responseCode !== 200) {
        this.setLocateError();
        return;
      }
      try {
        let res = JSON.parse(data.result.toString()) as AmapIpResponse;
        if (res.status === '1') {
          let name = res.city;
          if (!name || name.length === 0 || typeof name !== 'string') {
            name = res.province;
          }
          this.cityName = name;
          this.isNetworkError = false;
          if (res.adcode) {
            this.getWeatherDetails(res.adcode);
          } else {
            this.setLocateError();
          }
        } else {
          this.setLocateError();
        }
      } catch (e) {
        this.setLocateError();
      }
    });
  }

  // --- 核心功能：获取天气 ---
  getWeatherDetails(adcode: string) {
    let liveUrl = `https://restapi.amap.com/v3/weather/weatherInfo?city=${adcode}&key=${AMAP_KEY}&extensions=base`;
    let reqLive = http.createHttp();

    reqLive.request(liveUrl, {
      method: http.RequestMethod.GET,
      connectTimeout: 3000,
      readTimeout: 3000
    }, (err: Error, data: http.HttpResponse) => {
      if (!err && data.result) {
        try {
          let res = JSON.parse(data.result.toString()) as AmapLiveResponse;
          if (res.status === '1' && res.lives.length > 0) {
            let live = res.lives[0];
            this.currentTemp = live.temperature;
            this.aqiValue = live.humidity;
            this.aqiLevel = Number(live.humidity) > 300 ? '差' : '优';
            this.isNetworkError = false;
          } else {
            this.isNetworkError = true;
          }
        } catch (e) {
          this.isNetworkError = true;
        }
      } else {
        this.isNetworkError = true;
      }
    });

    let forecastUrl = `https://restapi.amap.com/v3/weather/weatherInfo?city=${adcode}&key=${AMAP_KEY}&extensions=all`;
    let reqForecast = http.createHttp();

    reqForecast.request(forecastUrl, {
      method: http.RequestMethod.GET,
      connectTimeout: 3000,
      readTimeout: 3000
    },
      (err: Error, data: http.HttpResponse) => {
        this.isRefreshing = false;
        if (this.showUpdateTips) {
          this.updateTips = "更新完成";
          this.isUpdateComplete = true;
          setTimeout(() => {
            this.hideUpdateTips();
          }, 800);
        }

        if (!err && data.result) {
          try {
            let res = JSON.parse(data.result.toString()) as AmapForecastResponse;
            if (res.status === '1' && res.forecasts.length > 0) {
              let casts = res.forecasts[0].casts;
              if (casts.length > 0) {
                this.highTemp = casts[0].daytemp;
                this.lowTemp = casts[0].nighttemp;
              }
              this.WeatherConditions = casts[0].dayweather;
              this.bgColors = getBackgroundByWeather(this.WeatherConditions);

              let threeDays = casts.slice(0, 3);
              this.forecasts = threeDays.map((item, index) => {
                let weekStr = "";
                if (index === 0) {
                  weekStr = "今天";
                } else if (index === 1) {
                  weekStr = "明天";
                } else {
                  const weeks = ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"];
                  weekStr = weeks[parseInt(item.week)];
                }
                return {
                  date: item.date,
                  dayWeather: item.dayweather,
                  nightWeather: item.nightweather,
                  dayTemp: item.daytemp,
                  nightTemp: item.nighttemp,
                  weekStr: weekStr
                } as WeatherModel;
              });
              this.updateCurrentLocationFromState();
              this.isSwitchingCity = false;
            }
          } catch (e) {
            this.isSwitchingCity = false;
          }
        } else {
          this.setLocateError();
          this.isSwitchingCity = false;
        }
      });
  }

  // --- 跳转系统 WiFi 设置 ---
  openNetworkSettings() {
    let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    let want: Want = {
      bundleName: 'com.huawei.hmos.settings',
      abilityName: 'com.huawei.hmos.settings.MainAbility',
      uri: 'wifi_entry'
    };
    context.startAbility(want).catch(() => {
      this.handleRefresh();
    });
  }

  // --- 手动下拉刷新逻辑 ---
  handleRefresh() {
    if (this.isSwitchingCity) {
      return;
    }
    this.isRefreshing = true;
    this.showUpdateTips = true;
    this.isUpdateComplete = false;
    this.updateTips = "正在更新...";
    this.getUIContext().animateTo({ duration: 300 }, () => {
      this.updateTipsHeight = 30;
      this.updateTipsOpacity = 1;
    });
    this.checkNetworkAndLocate();
  }

  // --- 获取对应的天气图标 ---
  getWeatherIcon(weatherStr: string): Resource {
    if (weatherStr.includes('大雨')) {
      return $r('app.media.ic_weather_heavy_rain');
    } else if (weatherStr.includes('小雨')) {
      return $r('app.media.ic_weather_light_rain');
    } else if (weatherStr.includes('多云') || weatherStr.includes('阴')) {
      return $r('app.media.ic_weather_cloudy');
    } else {
      return $r('app.media.ic_weather_sunny');
    }
  }

  // --- 更新 城市管理页面 “当前位置” 卡片数据 ---
  updateCurrentLocationFromState() {
    this.currentLocation = {
      cityName: this.cityName,
      CurrentTemperature: this.currentTemp,
      weather: this.WeatherConditions,
      lowTemp: this.lowTemp,
      highTemp: this.highTemp,
    };
  }

  // 路由表
  @Builder
  PagesMap(name: string) {
    if (name === 'City_Management') {
      City_Management()
    } else if (name === 'News') {
      News()
    } else if (name === 'User') {
      User()
    }
  }

  // ==========================================
  // 【新增】菜单弹窗构建器 (bindPopup 使用) 使用官方 bindPopup (进阶方案)这是 HarmonyOS 最标准的气泡弹窗做法。它会自动计算位置，不需要你手动写 margin，而且点击空白处会自动关闭。
  // ==========================================
  @Builder
  MenuBuilder() {
    Column() {
      // 菜单项1：新闻
      Text('新闻')
        .fontSize(16)
        .fontColor('#333')
        .width('100%')
        .height(44)
        .textAlign(TextAlign.Start) // 文字左对齐
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.showMenu = false; // 关闭弹窗
          this.pageStack.pushPath({ name: 'News' });
        })

      // 分割线
      Divider()
        .color('#EEE')
        .strokeWidth(1)
        .margin({ left: 12, right: 12 })

      // 菜单项2：我的
      Text('我的')
        .fontSize(16)
        .fontColor('#333')
        .width('100%')
        .height(44)
        .textAlign(TextAlign.Start)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.showMenu = false; // 关闭弹窗
          this.pageStack.pushPath({ name: 'User' });
        })
    }
    .width(130) // 设置弹窗内容的宽度
    .padding({ top: 4, bottom: 4 })
  }

  // --- UI 构建 ---
  build() {
    Navigation(this.pageStack) {
      Stack() {
        Column()
          .width('100%').height('100%')
          // .linearGradient({ angle: 180, colors: this.bgColors })
          .backgroundColor(Color.Blue)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

        Refresh({ refreshing: $$this.isRefreshing }) {
          Stack() {
            Scroll() {
              Column() {
                // ==========================================
                // 【修改】顶部操作栏 (删除原有的 Stack 包裹和 if (showMenu) 逻辑)
                // ==========================================
                Row() {
                  Blank()
                  // 右上角图标 (加号)
                  SymbolGlyph($r('sys.symbol.plus'))
                    .width(24)
                    .height(24)
                    .fontColor([Color.White])
                    .margin({ right: 20 })
                    .onClick(() => {
                      this.pageStack.pushPath({ name: 'City_Management' })
                    })

                  // 【修改】更多图标 - 绑定 bindPopup
                  SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
                    .width(24)
                    .height(24)
                    .fontColor([Color.White])
                    .onClick(() => {
                      this.showMenu = !this.showMenu;
                    })
                    // 核心修改：使用系统原生气泡弹窗
                    .bindPopup(this.showMenu, {
                      builder: this.MenuBuilder, // 指定上面的 @Builder
                      placement: Placement.Bottom, // 指定显示在下方
                      popupColor: Color.White, // 气泡背景色
                      enableArrow: false, // 是否显示小三角
                      mask: false, // 不显示遮罩层(背景不发黑)
                      radius: 12,
                      onStateChange: (e) => {
                        // 当点击气泡外部区域导致气泡消失时，同步状态
                        if (!e.isVisible) {
                          this.showMenu = false;
                        }
                      }
                    })
                }
                .width('100%').height(50).padding({ right: 20 })

                // ==========================================
                // 顶部操作栏结束
                // ==========================================

                // --- 核心信息区 ---
                Column() {
                  // 城市名
                  Row() {
                    Text(this.cityName)
                      .fontSize(32)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Color.White)
                  }.width('100%').justifyContent(FlexAlign.Start)

                  // 更新状态提示条
                  if (this.showUpdateTips) {
                    Row() {
                      if (this.isUpdateComplete) {
                        SymbolGlyph($r('sys.symbol.checkmark'))
                          .fontSize(18).fontColor([Color.White]).margin({ right: 6 })
                      } else {
                        SymbolGlyph($r('sys.symbol.cloud'))
                          .fontSize(18).fontColor([Color.White]).margin({ right: 6 })
                      }
                      Text(this.updateTips)
                        .fontSize(14).fontColor(Color.White)
                    }
                    .width('100%')
                    .justifyContent(FlexAlign.Start)
                    .height(this.updateTipsHeight)
                    .opacity(this.updateTipsOpacity)
                    .margin({ top: 5 })
                    .animation({ duration: 300 })
                  }

                  // 网络错误提示
                  if (this.isNetworkError) {
                    Row() {
                      Text("检查网络，获得当前位置天气")
                        .fontSize(14).fontColor('rgba(255, 255, 255, 0.8)')
                      SymbolGlyph($r('sys.symbol.eye'))
                        .fontSize(16)
                        .fontColor(['rgba(255, 255, 255, 0.8)'])
                        .margin({ left: 5 })
                    }
                    .width('100%').justifyContent(FlexAlign.Start)
                    .margin({ top: 8 })
                    .onClick(() => {
                      this.openNetworkSettings();
                    })
                  }

                  Blank().height(10)

                  // 温度大字
                  Row() {
                    Text(this.currentTemp)
                      .fontSize(120).fontWeight(FontWeight.Lighter).fontColor(Color.White)
                    Text("°")
                      .fontSize(60).fontColor(Color.White).margin({ top: -60 })
                  }.width('100%')

                  // 天气描述
                  Row() {
                    Text(this.WeatherConditions + "  ")
                      .fontSize(20)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Color.White)
                    Text(`最高${this.highTemp}° 最低${this.lowTemp}°`)
                      .fontSize(20)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Color.White)
                  }.width('100%').margin({ top: 5 })

                  // AQI
                  Row() {
                    Circle({ width: 10, height: 10 }).fill(Color.Green).margin({ right: 8 })
                    Text(`${this.aqiLevel} ${this.aqiValue}`).fontSize(14).fontColor(Color.White)
                  }
                  .backgroundColor('rgba(255, 255, 255, 0.2)')
                  .padding({
                    left: 12,
                    right: 12,
                    top: 6,
                    bottom: 6
                  })
                  .borderRadius(16)
                  .margin({ top: 15 })
                  .alignSelf(ItemAlign.Start)
                }
                .padding({ left: 20, right: 20 })

                Blank().layoutWeight(1)

                // 底部天气预报
                if (this.forecasts.length > 0) {
                  Column() {
                    Column() {
                      ForEach(this.forecasts, (item: WeatherModel, index: number) => {
                        Row() {
                          Text(item.weekStr)
                            .fontColor(Color.White).fontSize(16).width('20%')
                          Text(item.dayWeather)
                            .fontColor(Color.White).fontSize(16).width('20%')
                          Image(this.getWeatherIcon(item.dayWeather))
                            .width(30).height(30).objectFit(ImageFit.Contain).margin({ right: 10 })
                          Text(`${item.nightTemp}°`).fontColor('rgba(255,255,255,0.7)').fontSize(16)
                          Text(`${item.dayTemp}°`).fontColor(Color.White).fontSize(16)
                        }
                        .width('100%')
                        .padding({ top: 8, bottom: 8 })
                        .justifyContent(FlexAlign.SpaceAround)

                        if (index !== this.forecasts.length - 1) {
                          Divider().color('rgba(255, 255, 255, 0.15)').strokeWidth(0.5)
                        }
                      })
                    }
                    .width('100%')

                    Button("查看近15日天气")
                      .type(ButtonType.Normal)
                      .fontColor(Color.White)
                      .width('100%')
                      .height(55)
                      .borderRadius(20)
                      .margin({ top: 20 })
                      .hitTestBehavior(HitTestMode.Block)
                      .stateStyles({
                        pressed: {
                          .backgroundColor('rgba(255, 255, 255, 0.3)')
                        },
                        normal: {
                          .backgroundColor('rgba(255, 255, 255, 0.2)')
                        }
                      })
                      .animation({ duration: 200 })

                  }
                  .width('92%')
                  .stateStyles({
                    pressed: {
                      .backgroundColor('rgba(255, 255, 255, 0.1)')
                    },
                    normal: {
                      .backgroundColor('rgba(0, 0, 0, 0.2)')
                    }
                  })
                  .animation({ duration: 250, curve: Curve.Friction })
                  .backdropBlur(10)
                  .borderRadius(30)
                  .padding(20)
                  .margin({ bottom: 5 })
                  .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
                }
              }
              .width('100%')
              .constraintSize({ minHeight: '100%' })
            }
            .width('100%')
            .height('100%')
            .scrollBar(BarState.Off)
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          }
          .width('100%')
          .height('100%')
        }
        .onRefreshing(() => {
          this.handleRefresh();
        })
        .width('100%')
        .height('100%')
      }
    }
    .navDestination(this.PagesMap)
    .backgroundColor(Color.Red)
  }
}