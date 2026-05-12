import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 获取主窗口
    let windowClass: window.Window = windowStage.getMainWindowSync();
    // 设置窗口为全屏布局（沉浸式控制核心）
    // 设置为 true 后，布局会延伸到状态栏和导航栏下方
    windowClass.setWindowLayoutFullScreen(true, (err) => {
      if (err.code) {
        console.error('设置全屏布局失败: ' + JSON.stringify(err));
        return;
      }
      console.info('设置全屏布局成功');
    });

    // (可选) 设置状态栏文字颜色，防止背景太亮看不清时间
    windowClass.setWindowSystemBarProperties({ statusBarContentColor: '#FFFFFF' });

    // 加载页面入口（保持原样即可）
    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        console.error('加载页面内容失败: ' + JSON.stringify(err));
        return;
      }
    });

    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}