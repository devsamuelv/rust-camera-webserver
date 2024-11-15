FROM ubuntu:24.04

WORKDIR /work
ENV PORT=3000 VIDEO_SOURCE=0

RUN apt update

RUN apt install git build-essential cmake -y

RUN git clone https://github.com/opencv/opencv.git
RUN git clone https://github.com/opencv/opencv_contrib.git

RUN mkdir -p build
WORKDIR /work/build

# RUN cmake -D CMAKE_BUILD_TYPE=Release -D CMAKE_INSTALL_PREFIX=/usr/local ..
RUN cmake -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules ../opencv
RUN cmake --build .

RUN make install

RUN apt install libclang-dev libopencv-dev make clang g++-aarch64-linux-gnu gcc-aarch64-linux-gnu libopencv-video-dev -y
