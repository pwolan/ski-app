from firebase_functions import storage_fn, options
from firebase_admin import initialize_app, firestore, storage
import logging
import os
import tempfile


# Initialize Firebase Admin
initialize_app()

@storage_fn.on_object_finalized(
    region="us-west1",
    memory=options.MemoryOption.GB_4,
    timeout_sec=540,
)
def on_video_uploaded(event: storage_fn.CloudEvent[storage_fn.StorageObjectData]):
    """
    Triggers when a new object is finalized (uploaded) to Firebase Storage.
    Downloads the video, runs YOLOv8 Pose estimation, and saves results to Firestore.
    """
    bucket_name = event.data.bucket
    file_path = event.data.name
    content_type = event.data.content_type

    print(f"DEBUG: Triggered with file_path={file_path}, content_type={content_type}")

    # Only process videos in the 'videos/' folder
    if not file_path.startswith("videos/"):
        logging.info(f"Skipping file: {file_path} (not a video in videos/ folder)")
        return

    logging.info(f"Processing started for: {file_path}")

    # Create a temporary file to download the video
    _, temp_local_filename = tempfile.mkstemp(suffix=".mp4")

    try:
        # Download the file from the bucket
        bucket = storage.bucket(bucket_name)
        blob = bucket.blob(file_path)
        blob.download_to_filename(temp_local_filename)
        logging.info(f"Video downloaded to {temp_local_filename}")

        # Load YOLO model
        from ultralytics import YOLO
        import numpy as np
        # The model will download on first run to /tmp/ or cache dir
        model = YOLO('yolov8n-pose.pt')

        # Run inference
        results = model(temp_local_filename, stream=True)

        video_keypoints = []

        # Process results generator
        for r in results:
            # keypoints.xyn returns normalized coordinates (0-1)
            # Shape is (1, 17, 2) or (N, 17, 2) if multiple detections
            # We assume single skier or take the first one for simplicity now
            if r.keypoints is not None and len(r.keypoints.xyn) > 0:
                # Take the first detected person's keypoints
                # Convert to list for JSON serialization
                # xyn gives [x, y] normalized
                # Flatten the array to [x1, y1, x2, y2...] to avoid nested arrays in Firestore
                frame_kpts = r.keypoints.xyn[0].flatten().tolist()
                video_keypoints.append({"points": frame_kpts})
            else:
                video_keypoints.append({"points": []}) # No person detected in frame

        logging.info(f"Inference complete. Processed {len(video_keypoints)} frames.")

        # Save results to Firestore
        db = firestore.client()
        # Use filename as document ID (replacing slashes to avoid issues if needed, but here simple is fine)
        # file_path is like 'videos/12345.mp4', let's use just the '12345.mp4' part or a unique ID.
        doc_id = file_path.split("/")[-1]

        db.collection("video_results").document(doc_id).set({"frames": video_keypoints})

        logging.info(f"Successfully saved results to Firestore for {doc_id}")

    except Exception as e:
        logging.error(f"Error processing video {file_path}: {e}")
