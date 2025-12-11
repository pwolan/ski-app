from firebase_functions import storage_fn
from firebase_admin import initialize_app, firestore
import logging

# Initialize Firebase Admin
initialize_app()

@storage_fn.on_object_finalized(region="us-west1")
def on_video_uploaded(event: storage_fn.CloudEvent[storage_fn.StorageObjectData]):
    """
    Triggers when a new object is finalized (uploaded) to Firebase Storage.
    """
    bucket_name = event.data.bucket
    file_path = event.data.name
    content_type = event.data.content_type

    # Only process files in the 'videos/' directory and ensure it's a video
    if not file_path.startswith("videos/") or (content_type and not content_type.startswith("video/")):
        logging.info(f"Ignoring file: {file_path} (Type: {content_type})")
        return

    logging.info(f"Processing new video upload: {file_path} in bucket {bucket_name}")

    try:
        # MOCK PROCESSING LOGIC
        # In the future, this is where we would download the file,
        # run the ML model, and generate real keypoints.

        # Mock Keypoints Data (for demonstration)
        mock_results = {
            "status": "processed",
            "file_path": file_path,
            "processed_at": firestore.SERVER_TIMESTAMP,
            "keypoints": [
                {"frame": 0, "points": [{"x": 0.5, "y": 0.5, "conf": 0.9}, {"x": 0.6, "y": 0.6, "conf": 0.8}]},
                {"frame": 1, "points": [{"x": 0.51, "y": 0.51, "conf": 0.9}, {"x": 0.61, "y": 0.61, "conf": 0.8}]},
                # ... would be more data
            ],
            "analysis_summary": "Good technique detected (Mock Analysis)"
        }

        # Save results to Firestore
        db = firestore.client()
        # Use filename as document ID (replacing slashes to avoid issues if needed, but here simple is fine)
        # file_path is like 'videos/12345.mp4', let's use just the '12345.mp4' part or a unique ID.
        doc_id = file_path.split("/")[-1]

        db.collection("video_results").document(doc_id).set(mock_results)

        logging.info(f"Successfully saved mock results to Firestore for {doc_id}")

    except Exception as e:
        logging.error(f"Error processing video {file_path}: {e}")
