"""Desenha os ossos (UV) sobre o recorte para conferir os pivôs à mão."""
import sys, json, cv2, common

def draw(identity, bones, out, scale=2):
	rgb, a = common.load_crop(identity)
	im = cv2.resize(common.preview(rgb, a), None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)
	h, w = im.shape[:2]
	for name, (p0, p1) in bones.items():
		a0 = (int(p0[0]*w), int(p0[1]*h)); a1 = (int(p1[0]*w), int(p1[1]*h))
		cv2.line(im, a0, a1, (0, 255, 120), 2)
		cv2.circle(im, a0, 5, (0, 220, 255), -1)
		cv2.putText(im, name, (a0[0]+6, a0[1]-4), 0, 0.45, (255, 255, 255), 1)
	cv2.imwrite(out, im)

if __name__ == "__main__":
	data = json.load(open(sys.argv[1]))
	for k, bones in data.items():
		draw(int(k), bones, sys.argv[2] % int(k))
