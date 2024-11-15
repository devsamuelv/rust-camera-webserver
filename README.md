# Rust Camera Webserver (Experiment)
This was a quick evening project to implement a camera server in rust using opencv.
it uses rust std network library to handle requests and stream data.
Not to mention I used this project as an opportunity to experiment with docker for iot testing with rust. 
It yielded some interesting results and was an fun project overall.

**Note**: The code to stream the camera data came from stackoverflow I can't find the post anymore unfortunately :(

## Lessons Learned
- Using docker for simulation and testing is **very slow** even with multi-stage builds, maybe there's a way around this
however I didn't find it while working on this. 
- Support for streaming camera data in rust is limited in libraries like rocket.rs which is why I used the standard library.

### Some Required Packages for Cross Compilation for aarch

- sudo apt install g++-aarch64-linux-gnu
- sudo apt install gcc-aarch64-linux-gnu
