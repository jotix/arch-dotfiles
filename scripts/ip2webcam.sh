#!/bin/bash

gst-launch-1.0 -vt souphttpsrc location=http://192.168.1.34:8080/video is-live=true ! multipartdemux ! decodebin ! videoconvert ! v4l2sink device=/dev/video0   
