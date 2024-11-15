use std::io::{Error, ErrorKind};
use std::net::SocketAddr;

use opencv::core::Vector;
use opencv::videoio::VideoCapture;
use opencv::{imgcodecs, prelude::*, videoio};
use tokio::io::AsyncWriteExt;
use tokio::net::{TcpListener, TcpStream};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let env_port = std::env::var("PORT").expect("Please define webserver port!");
    let env_cam_source = std::env::var("VIDEO_SOURCE").expect("Please define video source!");

    let addr = SocketAddr::from(([0, 0, 0, 0], env_port.parse::<u16>().unwrap()));
    let listener = TcpListener::bind(addr).await.unwrap();

    let mut cam =
        videoio::VideoCapture::new(env_cam_source.parse::<i32>().unwrap(), videoio::CAP_V4L2)
            .unwrap();

    cam.set(videoio::CAP_PROP_FRAME_HEIGHT, 1080.0).unwrap();
    cam.set(videoio::CAP_PROP_FRAME_WIDTH, 720.0).unwrap();

    let opened = videoio::VideoCapture::is_opened(&cam).unwrap();
    if !opened {
        panic!("Unable to open camera");
    }

    println!("Server running!");

    loop {
        let (mut stream, _) = listener.accept().await?;

        stream_data(&mut stream, &mut cam).await;
    }
}

async fn stream_data(stream: &mut TcpStream, cam: &mut VideoCapture) {
    let response = format!(
        "HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n"
    );
    stream.write_all(response.as_bytes()).await.unwrap();

    let mut frame = Mat::default();
    let mut output_buff: Vector<u8> = Vector::<u8>::new();

    loop {
        cam.read(&mut frame).unwrap();
        output_buff.clear();

        imgcodecs::imencode_def(".jpg", &frame, &mut output_buff).expect("encode");

        let image_data = format!(
            "--frame\r\nContent-Type: image/jpeg\r\nContent-Length: {}\r\n\r\n",
            output_buff.len(),
        );

        // This code is gross! However, it works so :)
        let op1 = catch_stream(stream.write_all(image_data.as_bytes()).await);
        let op2 = catch_stream(stream.write_all(output_buff.as_slice()).await);
        let op3 = catch_stream(stream.write_all(b"\r\n").await);
        let op4 = catch_stream(stream.flush().await);

        // If tcp stream is broken exit loop.
        if op1 == true || op2 == true || op3 == true || op4 == true {
            break;
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
