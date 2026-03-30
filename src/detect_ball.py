import cv2
import numpy as np

cap = cv2.VideoCapture("/Users/adamzhu/Projects/pinpoint/data/darren-tang-equinoxsolid.mov")

# lane corners
lane_corners = np.array([
    [489, 916],
    [1061, 274],
    [1314, 279],
    [1333, 941]
], dtype=np.int32)

# background subtractor
bg_subtractor = cv2.createBackgroundSubtractorMOG2(
    history=500,
    varThreshold=50,
    detectShadows=False
)

# the lane's vertical midpoint — ignore reflections below this
LANE_TOP_Y = 274
LANE_BOTTOM_Y = 941
LANE_MIDPOINT_Y = (LANE_TOP_Y + LANE_BOTTOM_Y) // 2

# ignore the pin area — top 25% of the lane
PIN_ZONE_Y = LANE_TOP_Y + (LANE_BOTTOM_Y - LANE_TOP_Y) // 4

while True:
    ret, frame = cap.read()

    if not ret:
        break

    # Step 1: create lane mask
    lane_mask = np.zeros(frame.shape[:2], dtype=np.uint8)
    cv2.fillPoly(lane_mask, [lane_corners], 255)

    # Step 2: block out the pin zone at the top
    lane_mask[:PIN_ZONE_Y, :] = 0

    # Step 3: block out the bottom half to remove reflections
    lane_mask[LANE_MIDPOINT_Y:, :] = 0

    # Step 4: apply background subtraction
    fg_mask = bg_subtractor.apply(frame)

    # Step 5: combine lane mask with motion mask
    combined_mask = cv2.bitwise_and(fg_mask, fg_mask, mask=lane_mask)

    # Step 6: clean up the mask
    kernel = np.ones((5, 5), np.uint8)
    combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_OPEN, kernel)
    combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_CLOSE, kernel)

    # Step 7: blur and detect circles
    blurred = cv2.GaussianBlur(combined_mask, (9, 9), 2)
    circles = cv2.HoughCircles(
        blurred,
        cv2.HOUGH_GRADIENT,
        dp=1,
        minDist=50,
        param1=50,
        param2=15,
        minRadius=20,
        maxRadius=80
    )

    # Step 8: filter circles by size and draw
    if circles is not None:
        circles = np.round(circles[0, :]).astype("int")
        for (x, y, r) in circles:
            # ignore if circle is too large (likely the hand/bowler)
            if r > 60:
                continue
            # ignore if circle is too small (noise)
            if r < 15:
                continue
            cv2.circle(frame, (x, y), r, (0, 255, 0), 3)
            cv2.circle(frame, (x, y), 3, (0, 0, 255), -1)

    # draw lane boundary and zones for debugging
    cv2.polylines(frame, [lane_corners], isClosed=True, color=(255, 0, 0), thickness=2)
    cv2.line(frame, (0, LANE_MIDPOINT_Y), (frame.shape[1], LANE_MIDPOINT_Y), (0, 255, 255), 1)
    cv2.line(frame, (0, PIN_ZONE_Y), (frame.shape[1], PIN_ZONE_Y), (0, 165, 255), 1)

    cv2.imshow("PinPoint - Motion Mask", combined_mask)
    cv2.imshow("PinPoint - Ball Detection", frame)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()