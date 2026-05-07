from ultralytics import YOLO
model = YOLO(r"C:\Users\Kangkang\Desktop\FWCX2026\DataTraining2\yolo_cls_25cls\weights\best.pt")
model.export(format='onnx', imgsz=224, opset=12, dynamic=False)