"""Package a square, one-class YOLO11 detection export for ScoutVision."""

import argparse
from pathlib import Path

import onnx


def export(source, destination, prefix):
    model = onnx.shape_inference.infer_shapes(onnx.load(source))
    graph = model.graph
    values = {value.name: value for value in graph.value_info}

    def dimensions(value):
        return tuple(dim.dim_value for dim in value.type.tensor_type.shape.dim)

    batch, channels, height, width = dimensions(graph.input[0])
    if (batch, channels) != (1, 3) or width != height or width not in (480, 640):
        raise ValueError("Export YOLO at imgsz=480 or 640 with batch=1 and dynamic=False.")
    sides = [width // stride for stride in (8, 16, 32)]
    if dimensions(graph.output[0]) != (1, 5, sum(side**2 for side in sides)):
        raise ValueError("Export a one-class YOLO11 model with NMS disabled.")
    for level, side in enumerate(sides):
        name = f"/model.23/cv3.{level}/cv3.{level}.1/cv3.{level}.1.1/act/Mul_output_0"
        value = values[name]
        if dimensions(value) != (1, 128, side, side):
            raise ValueError(f"Unexpected classification feature shape at level {level}.")
        graph.output.append(value)
    onnx.checker.check_model(model)
    data = model.SerializeToString()
    destination.mkdir(parents=True, exist_ok=True)
    part_size = (len(data) + 1) // 2
    if part_size > 25 * 1024**2:
        raise ValueError("The model exceeds the limit for two Cloudflare Pages assets.")
    for index in range(2):
        (destination / f"{prefix}-{index+1}.bin").write_bytes(data[index*part_size:(index+1)*part_size])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("onnx", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("prefix")
    args = parser.parse_args()
    export(args.onnx, args.destination, args.prefix)
