"""Train Solar's robot detector locally, or check the environment with --check."""

import argparse
import json
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VISION_DATA = ROOT / ".solar_rankings_cache" / "vision"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check setup without training.")
    parser.add_argument("--epochs", type=int, default=50)
    parser.add_argument("--batch-size", type=int, default=2)
    parser.add_argument("--dataset", type=Path, default=VISION_DATA / "override-robots-v1")
    args = parser.parse_args()
    if args.epochs < 1 or args.batch_size < 1:
        parser.error("Epochs and batch size must be positive.")

    import torch
    from rfdetr import RFDETRLarge

    if not torch.cuda.is_available():
        raise RuntimeError("CUDA is unavailable. Use the Solar environment with GPU-enabled PyTorch.")
    print(f"GPU: {torch.cuda.get_device_name(0)}", flush=True)
    print(f"PyTorch: {torch.__version__}, CUDA: {torch.version.cuda}", flush=True)
    # Exercise an actual CUDA operation and backward pass before training.
    sample = torch.randn(32, 32, device="cuda", requires_grad=True)
    sample.square().mean().backward()
    torch.cuda.synchronize()
    del sample

    dataset = args.dataset.resolve()
    for split in ("train", "valid", "test"):
        folder = dataset / split
        with (folder / "_annotations.coco.json").open(encoding="utf-8") as file:
            labels = json.load(file)
        images = {image["id"]: image for image in labels["images"]}
        categories = {category["id"] for category in labels["categories"]}
        for image in images.values():
            if not (folder / image["file_name"]).is_file():
                raise FileNotFoundError(folder / image["file_name"])
        for annotation in labels["annotations"]:
            if annotation["image_id"] not in images or annotation["category_id"] not in categories:
                raise ValueError(f"Invalid annotation reference in {split}.")
            box = annotation["bbox"]
            if len(box) != 4 or box[2] <= 0 or box[3] <= 0:
                raise ValueError(f"Invalid bounding box in {split}.")
        if not images or not labels["annotations"]:
            raise ValueError(f"The {split} split needs images and annotations.")
        print(f"{split}: {len(images)} images, {len(labels['annotations'])} boxes", flush=True)

    if args.check:
        print("Setup checks passed. Training has not started.", flush=True)
        return

    output = VISION_DATA / "runs" / datetime.now().strftime("large-%Y%m%d-%H%M%S-%f")
    print(f"Saving training output to {output}", flush=True)
    model = RFDETRLarge()
    model.train(
        dataset_dir=str(dataset),
        output_dir=str(output),
        device="cuda",
        epochs=args.epochs,
        batch_size=args.batch_size,
        grad_accum_steps=8,
        num_workers=0,
        early_stopping=True,
        early_stopping_patience=10,
        tensorboard=False,
        wandb=False,
    )


if __name__ == "__main__":
    main()
