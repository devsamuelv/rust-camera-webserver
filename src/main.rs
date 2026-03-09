use std::io::{Error, ErrorKind};
use std::net::SocketAddr;
use std::time::Duration;

use jpegxl_rs::encoder_builder;
use libcamera::camera::CameraConfigurationStatus;
use libcamera::camera_manager::CameraManager;
use libcamera::framebuffer_allocator::{FrameBuffer, FrameBufferAllocator};
use libcamera::framebuffer_map::MemoryMappedFrameBuffer;
use libcamera::pixel_format::PixelFormat;
use libcamera::stream::StreamRole;
use tokio::io::AsyncWriteExt;
use tokio::net::TcpListener;

const PIXEL_FORMAT_MJPEG: PixelFormat =
    PixelFormat::new(u32::from_le_bytes([b'M', b'J', b'P', b'G']), 0);

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let env_port_res = std::env::var("PORT");
    let mut env_port: String = String::from("3001");

    if env_port_res.is_ok() {
      env_port = env_port_res.unwrap();
    }

    let addr = SocketAddr::from(([0, 0, 0, 0], env_port.parse::<u16>().unwrap()));
    let listener = TcpListener::bind(addr).await.unwrap();

    let mgr = CameraManager::new().expect("camera");
    let cameras = mgr.cameras();
    let mut cam = cameras
        .iter()
        .next()
        .expect("no cameras found")
        .acquire()
        .unwrap();
    let mut cfgs = cam
        .generate_configuration(&[StreamRole::ViewFinder])
        .unwrap();

    cfgs.get_mut(0)
        .unwrap()
        .set_pixel_format(PIXEL_FORMAT_MJPEG);

    match cfgs.validate() {
        CameraConfigurationStatus::Valid => println!("Camera configuration valid!"),
        CameraConfigurationStatus::Adjusted => {
            println!("Camera configuration was adjusted: {cfgs:#?}")
        }
        CameraConfigurationStatus::Invalid => panic!("Error validating camera configuration"),
    }

    // Ensure that pixel format was unchanged
    assert_eq!(
        cfgs.get(0).unwrap().get_pixel_format(),
        PIXEL_FORMAT_MJPEG,
        "MJPEG is not supported by the camera"
    );

    cam.configure(&mut cfgs)
        .expect("Unable to configure camera");

    let mut alloc = FrameBufferAllocator::new(&cam);

    // Allocate frame buffers for the stream
    let cfg = cfgs.get(0).unwrap();
    let cam_stream = cfg.stream().unwrap();
    let alloc_buffers = alloc.alloc(&cam_stream).unwrap();
    println!("Allocated {} buffers", alloc_buffers.len());

    // Convert FrameBuffer to MemoryMappedFrameBuffer, which allows reading &[u8]
    let buffers = alloc_buffers
        .into_iter()
        .map(|buf| MemoryMappedFrameBuffer::new(buf).unwrap())
        .collect::<Vec<_>>();

    // Create capture requests and attach buffers
    let mut reqs = buffers
        .into_iter()
        .map(|buf| {
            let mut req = cam.create_request(None).unwrap();
            req.add_buffer(&cam_stream, buf).unwrap();
            req
        })
        .collect::<Vec<_>>();

    // Completed capture requests are returned as a callback
    let (tx, rx) = std::sync::mpsc::channel();
    cam.on_request_completed(move |req| {
        tx.send(req).unwrap();
    });

    cam.start(None).unwrap();

    println!("Server running!");

    // Jpeg XL
    let mut encoder = encoder_builder()
        .speed(jpegxl_rs::encode::EncoderSpeed::Falcon)
        .build()
        .unwrap();

    loop {
        let (mut stream, _) = listener.accept().await?;

        let response = format!(
            "HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n"
        );
        stream.write_all(response.as_bytes()).await.unwrap();

        loop {
            if reqs.len() > 0 {
                let reqs = reqs.pop().unwrap();
                cam.queue_request(reqs).map_err(|(_, e)| e).unwrap();

                println!("Waiting for camera request execution");
                // Allow a bit more time for first exposure/conversion to complete on slower cameras.
                let req = rx
                    .recv_timeout(Duration::from_secs(5))
                    .expect("Camera request failed");

                println!("Camera request {req:?} completed!");
                println!("Metadata: {:#?}", req.metadata());

                // Get framebuffer for our stream
                let framebuffer: &MemoryMappedFrameBuffer<FrameBuffer> =
                    req.buffer(&cam_stream).unwrap();

                // MJPEG format has only one data plane containing encoded jpeg data with all the headers
                let planes = framebuffer.data();
                let jpeg_data = planes.first().unwrap();

                let encoder_result = encoder.encode_jpeg(*jpeg_data).unwrap();
                let image_data_prefix = format!(
                    "--frame\r\nContent-Type: image/jxl\r\nContent-Length: {}\r\n\r\n",
                    encoder_result.len(),
                );
                let jxl_data = encoder_result.iter().as_slice();

                // This code is gross! However, it works so :)
                let op1 = catch_stream(stream.write_all(image_data_prefix.as_bytes()).await);
                let op2 = catch_stream(stream.write_all(jxl_data).await);
                let op3 = catch_stream(stream.write_all(b"\r\n").await);
                let op4 = catch_stream(stream.flush().await);

                // If tcp stream is broken exit loop.
                if op1 == true || op2 == true || op3 == true || op4 == true {
                    break;
                }
            } else {
                // Convert FrameBuffer to MemoryMappedFrameBuffer, which allows reading &[u8]
                let new_alloc_buffers = alloc.alloc(&cam_stream).unwrap();
                let buffers = new_alloc_buffers
                    .into_iter()
                    .map(|buf| MemoryMappedFrameBuffer::new(buf).unwrap())
                    .collect::<Vec<_>>();

                reqs = buffers
                    .into_iter()
                    .map(|buf| {
                        let mut req = cam.create_request(None).unwrap();
                        req.add_buffer(&cam_stream, buf).unwrap();
                        req
                    })
                    .collect::<Vec<_>>();
            }
        }
    }
}

fn catch_stream(statement: Result<(), Error>) -> bool {
    match statement {
        Ok(_) => {
            return false;
        }
        Err(e) => {
            if e.kind() == ErrorKind::BrokenPipe {
                return true;
            } else {
                return false;
            }
        }
    }
}
