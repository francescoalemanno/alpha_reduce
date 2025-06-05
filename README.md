# alpha_reduce

A Zig utility for converting images to greyscale with alpha channel transparency based on statistical thresholding.

## What it does

- Converts colour images to greyscale
- Calculates statistical properties (mean, standard deviation) of bright pixels
- Applies adaptive thresholding using statistical analysis
- Generates alpha channel based on pixel intensity
- Outputs processed images with `_t.png` suffix

## Usage

```bash
alpha_reduce image1.jpg image2.png image3.bmp
```

Processes each input file and creates corresponding `*_t.png` outputs.

## Algorithm

1. Convert image to greyscale (average of RGB channels)
2. Calculate mean and standard deviation of pixels with brightness > 0.5
3. Set threshold as `mean - 1.9 × standard_deviation`
4. Normalise pixel values against threshold
5. Apply gamma correction (γ = 4.0)
6. Generate alpha channel where transparency increases with brightness

## Building

Requires Zig and the `zigimg` library.

```bash

zig build
```

## Dependencies

- [zigimg](https://github.com/zigimg/zigimg) - Image processing library for Zig