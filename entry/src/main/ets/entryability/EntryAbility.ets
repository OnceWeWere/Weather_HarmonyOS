import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

// UIAbility 是应用的基本运行单元 负责管理应用的生命周期和窗口
// UIAbility 的主要职责：
//  1.生命周期管理：onCreate、onDestroy、onForeground、onBackground
//  2.窗口管理：onWindowStageCreate、onWindowStageDestroy
//  3.页面加载：通过 windowStage.loadContent() 加载 UI 页面

export default class EntryAbility extends UIAbility {
  // 1. Ability 创建
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 应用启动时调用，进行初始化配置
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  // 6. Ability 销毁
  onDestroy(): void {
    // 应用退出
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  // 2. 窗口阶段创建（关键：这里加载 UI）
  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 窗口已创建，加载主页面
    windowStage.loadContent('pages/StartPage', (err) => {
      // 页面加载回调：加载成功或失败的处理
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  // 5. 窗口阶段销毁
  onWindowStageDestroy(): void {
    // 窗口销毁，释放 UI 资源
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  // 3. 应用进入前台
  onForeground(): void {
    // 从后台切回前台
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  // 4. 应用进入后台
  onBackground(): void {
    // 应用切到后台
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}