import sys
import os
import cv2 as OpenCV
from PIL import Image
from threading import Thread

video = OpenCV.VideoCapture(f"videos/{sys.argv[1]}")

ImagePath = f"/etc/ob/tensor/images/{sys.argv[2]}"
FrameID = 0
CV2 = True

if os.path.exists(f"{ImagePath}") == False:
    os.mkdir(ImagePath)
    while CV2:
        try:
            success, image = video.read()
            if success:
                OpenCV.imwrite(f"{ImagePath}/{FrameID}.jpg", image)
            else:
                CV2 = False
            FrameID = FrameID+1
        except:
            pass