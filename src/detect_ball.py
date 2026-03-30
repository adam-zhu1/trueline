import cv2
import numpy as np

cap = cv2.VideoCapture("/Users/adamzhu/Projects/pinpoint/data/darren-tang-equinoxsolid.mov")

# define the lane corners as a trapezoid
# order: bottom-left, top-left, top-right, bottom-right
lane_corners = np.array([
    [489, 916],
    [1061, 274],
    [1314, 279],
    [1333, 941]
], dtype=np.int32)

while True:
    ret, frame = cap.read()

    if not ret:
        break

    # Step 1: create a blank black mask same size as frame
    lane_mask = np.zeros(frame.shape[:2], dtype=np.uint8)

    # Step 2: fill the trapezoid with white
    cv2.fillPoly(lane_mask, [lane_corners], 255)

    # Step 3: convert to grayscale
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (9, 9), 2)

    # Step 4: apply the lane mask — zero out everything outside the lane
    masked = cv2.bitwise_and(blurred, blurred, mask=lane_mask)

    # Step 5: detect circles only inside the lane
    circles = cv2.HoughCircles(
        masked,
        cv2.HOUGH_GRADIENT,
        dp=1,
        minDist=50,
        param1=50,
        param2=30,
        minRadius=20,
        maxRadius=150
    )

    # Step 6: draw detected circles
    if circles is not None:
        circles = np.round(circles[0, :]).astype("int")
        for (x, y, r) in circles:
            cv2.circle(frame, (x, y), r, (0, 255, 0), 3)
            cv2.circle(frame, (x, y), 3, (0, 0, 255), -1)

    # draw the lane boundary so we can see it
    cv2.polylines(frame, [lane_corners], isClosed=True, color=(255, 0, 0), thickness=2)

    # show both windows for debugging
    cv2.imshow("PinPoint - Lane Mask", lane_mask)
    cv2.imshow("PinPoint - Ball Detection", frame)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()