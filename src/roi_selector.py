import cv2

cap = cv2.VideoCapture("/Users/adamzhu/Projects/pinpoint/data/darren-tang-equinoxsolid.mov")
ret, frame = cap.read()
cap.release()

# make a copy to draw on
display = frame.copy()

def click(event, x, y, flags, param):
    if event == cv2.EVENT_LBUTTONDOWN:
        print(f"x={x}, y={y}")
        # draw a red dot where you clicked
        cv2.circle(display, (x, y), 5, (0, 0, 255), -1)
        # draw the coordinates as text next to the dot
        cv2.putText(display, f"({x},{y})", (x+10, y), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 1)
        cv2.imshow("Click the lane edges", display)

cv2.imshow("Click the lane edges", display)
cv2.setMouseCallback("Click the lane edges", click)
cv2.waitKey(0)
cv2.destroyAllWindows()