import io
import base64
from PIL import Image

def get_b64(path, max_dim=720, quality=80):
    im = Image.open(path)
    im.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, format='WEBP', quality=quality)
    return base64.b64encode(buf.getvalue()).decode('ascii')

empty_b64 = get_b64('screen/split/split_home_illustration.png', 720, 80)
banner_b64 = get_b64('screen/split/split_home_details_illus.png', 720, 80)

print(f"Empty illustration base64 length: {len(empty_b64)}")
print(f"Banner illustration base64 length: {len(banner_b64)}")

content = f"""import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

const String splitHomeIllustrationBase64 = '{empty_b64}';
const String splitHomeDetailsIllusBase64 = '{banner_b64}';

final Uint8List _emptyBytes = base64Decode(splitHomeIllustrationBase64);
final Uint8List _bannerBytes = base64Decode(splitHomeDetailsIllusBase64);

class SplitIllustration extends StatelessWidget {{
  final bool isBanner;
  final double? width;
  final double? height;
  final BoxFit fit;

  const SplitIllustration.emptyState({{super.key, this.width, this.height, this.fit = BoxFit.contain}})
      : isBanner = false;

  const SplitIllustration.banner({{super.key, this.width, this.height, this.fit = BoxFit.contain}})
      : isBanner = true;

  @override
  Widget build(BuildContext context) {{
    final bytes = isBanner ? _bannerBytes : _emptyBytes;
    return Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (ctx, err, stack) {{
        final assetPath = isBanner
            ? 'screen/split/split_home_details_illus.png'
            : 'screen/split/split_home_illustration.png';
        return Image.asset(
          assetPath,
          width: width,
          height: height,
          fit: fit,
        );
      }},
    );
  }}
}}
"""

with open('lib/screens/split/split_illustrations.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("lib/screens/split/split_illustrations.dart generated successfully!")
