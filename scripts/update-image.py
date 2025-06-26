import os
import json
import subprocess
import argparse


def prefetch_docker(image, tag):
    cmd = [
        "nix-prefetch-docker",
        "--json",
        "--image-name", image,
        "--image-tag", tag
    ]
    p = subprocess.run(cmd, stdout=subprocess.PIPE, check=True)
    return json.loads(p.stdout)


parser = argparse.ArgumentParser()
parser.add_argument("name")
parser.add_argument("--image")
parser.add_argument("--tag", default="main")

args = parser.parse_args()
path = os.path.join("packages", args.name, "image.json")

if args.image is not None:
    image = args.image
else:
    with open(path) as f:
        metadata = json.load(f)
    image = metadata["imageName"]

result = prefetch_docker(image, args.tag)

with open(path, "w") as f:
    json.dump(result, f, indent=2)
