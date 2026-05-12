import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common, abilityAccessCtrl, PermissionRequestResult } from '@kit.AbilityKit'; // 新增导入

export class CameraService {
  private cameraManager: camera.CameraManager | undefined;
  private captureSession: camera.Session | undefined;
  private cameraInput: camera.CameraInput | undefined;
  private previewOutput: camera.PreviewOutput | undefined;
  private previewOutputForReceiver: camera.PreviewOutput | undefined;

  private imageReceiver: image.ImageReceiver | undefined;
  private imageReceiverSurfaceId: string = '';

  private detecting: boolean = false;
  private frameCallback: ((pm: image.PixelMap) => void) | undefined;

  private frameCount: number = 0; // 用于节流

  /**
   * 一键启动（预览 + 图像流）
   */
  async checkAndStartCamera(context: common.UIAbilityContext, surfaceId: string) {
    let atManager = abilityAccessCtrl.createAtManager();
    try {
      // 向用户发起弹窗请求
      let data: PermissionRequestResult = await atManager.requestPermissionsFromUser(context, ['ohos.permission.CAMERA']);

      // 检查授权结果 (0 表示授权成功)
      if (data.authResults[0] !== 0) {
        console.error('[CameraService] 用户拒绝了相机权限');
        return;
      }
      console.log('[CameraService] 相机权限获取成功');
    } catch (err) {
      console.error(`[CameraService] 权限请求异常: ${JSON.stringify(err)}`);
      return;
    }

    this.cameraManager = camera.getCameraManager(context);

    let cameras = this.cameraManager.getSupportedCameras();
    if (cameras.length === 0) {
      console.error('没有可用摄像头');
      return;
    }

    let device = cameras[0] ?? cameras[1];

    let capability = this.cameraManager.getSupportedOutputCapability(
      device,
      camera.SceneMode.NORMAL_PHOTO
    );

    let previewProfiles = capability.previewProfiles;

    // 1. 优先寻找标准的 1080p (1920x1080) 16:9 分辨率
    let targetProfile = previewProfiles.find((profile) => {
      // 兼顾宽高属性在不同设备上可能互换的情况
      return (profile.size.width === 1920 && profile.size.height === 1080) ||
        (profile.size.width === 1080 && profile.size.height === 1920);
    });

    // 2. 如果没找到 1080p，寻找其他 16:9 的最高分辨率
    if (!targetProfile) {
      // 将支持的分辨率按像素总数从大到小排序
      let sortedProfiles = previewProfiles.sort((a, b) => {
        return (b.size.width * b.size.height) - (a.size.width * a.size.height);
      });

      targetProfile = sortedProfiles.find((profile) => {
        let max = Math.max(profile.size.width, profile.size.height);
        let min = Math.min(profile.size.width, profile.size.height);
        // 允许有一点点浮点数计算误差
        return Math.abs((max / min) - (16 / 9)) < 0.05;
      });

      // 3. 如果连 16:9 都没有（极少见），拿最高分辨率兜底
      if (!targetProfile) {
        targetProfile = sortedProfiles[0];
      }
    }

    let previewProfile = targetProfile;
    console.info(`[CameraService] 最终选定的相机分辨率: ${previewProfile.size.width} x ${previewProfile.size.height}`);

    // ====== 1. 创建 ImageReceiver（用于取帧）======
    let size: image.Size = {
      width: previewProfile.size.width,
      height: previewProfile.size.height
    };

    this.imageReceiver = image.createImageReceiver(size, image.ImageFormat.JPEG, 8);
    this.imageReceiverSurfaceId = await this.imageReceiver.getReceivingSurfaceId();

    // 注册帧监听
    this.onImageArrival(this.imageReceiver);

    // ====== 2. 创建 Session ======
    this.captureSession = this.cameraManager.createSession(camera.SceneMode.NORMAL_PHOTO);

    await this.captureSession.beginConfig();

    // ====== 3. CameraInput ======
    this.cameraInput = this.cameraManager.createCameraInput(device);
    await this.cameraInput.open();
    this.captureSession.addInput(this.cameraInput);

    // ====== 4. 预览输出（显示）======
    this.previewOutput = this.cameraManager.createPreviewOutput(
      previewProfile,
      surfaceId
    );

    // ====== 5. 预览输出（数据流）======
    this.previewOutputForReceiver = this.cameraManager.createPreviewOutput(
      previewProfile,
      this.imageReceiverSurfaceId
    );

    this.captureSession.addOutput(this.previewOutput);
    this.captureSession.addOutput(this.previewOutputForReceiver);

    await this.captureSession.commitConfig();
    await this.captureSession.start();

    console.log('[CameraService] 相机启动成功');
  }

  /**
   * 开始实时帧回调
   */
  startRealtimeDetection(callback: (pm: image.PixelMap) => void) {
    this.detecting = true;
    this.frameCallback = callback;
  }

  /**
   * 停止帧回调
   */
  stopDetection() {
    this.detecting = false;
  }

  /**
   * ImageReceiver 回调（核心）
   */
  private onImageArrival(receiver: image.ImageReceiver) {
    receiver.on('imageArrival', () => {
      receiver.readNextImage(async (err: BusinessError, nextImage: image.Image) => {
        if (err || !nextImage) {
          return;
        }

        if (!this.detecting) {
          nextImage.release();
          return;
        }

        // ===== 节流（降低压力）=====
        this.frameCount++;
        if (this.frameCount % 10 !== 0) { // 每2帧取1帧
          nextImage.release();
          return;
        }

        try {
          nextImage.getComponent(image.ComponentType.JPEG, async (err, comp) => {
            if (err || !comp || !comp.byteBuffer) {
              nextImage.release();
              return;
            }

            let width = nextImage.size.width;
            let height = nextImage.size.height;

            let pixelMap = await image.createPixelMap(comp.byteBuffer, {
              size: { width, height },
              srcPixelFormat: 8
            });

            //  回调给 UI
            if (this.frameCallback) {
              this.frameCallback(pixelMap);
            } else {
              pixelMap.release();
            }

            nextImage.release();
          });
        } catch (e) {
          console.error('[CameraService] 处理帧异常');
          nextImage.release();
        }
      });
    });
  }

  /**
   * 释放资源（非常重要）
   */
  async releaseCamera() {
    try {
      this.detecting = false;

      if (this.captureSession) {
        await this.captureSession.stop();
      }

      this.previewOutput?.release();
      this.previewOutputForReceiver?.release();
      this.cameraInput?.close();
      this.captureSession?.release();

      this.imageReceiver = undefined;

      console.log('[CameraService] 相机已释放');
    } catch (err) {
      console.error('[CameraService] 释放失败');
    }
  }
}