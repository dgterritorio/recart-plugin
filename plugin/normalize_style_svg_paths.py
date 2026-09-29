#!/usr/bin/env python3
"""Rewrite absolute SVG paths in a layer_styles dump to portable relative names.

QGIS stores a different directory on each machine. The tail is stable:
a QGIS library path ends in ``svg/<category>/<file>.svg``, and a CartTop
marker ends in ``simbolos/<file>.svg``. Query strings (``?fill=...``) are kept.
"""

import re
import sys

# An absolute .svg path at the start of an attribute value. Stops before '?'
# so fill/outline parameters stay put. Quotes are excluded so the match cannot
# run across XML attributes.
_ABS_SVG = re.compile(
    r'(?<=["\'=])'
    r'((?:file://)?'
    r'(?:[A-Za-z]:[/\\]|/)'
    r'[^"\'?\r\n]*?\.svg)',
    re.IGNORECASE,
)


def _directory_tail(path, dirname):
    """Return the text after the last ``/dirname/`` segment, or None."""
    normalized = path.replace('\\', '/')
    if normalized.lower().startswith('file://'):
        normalized = normalized[7:]
    needle = '/' + dirname.lower() + '/'
    idx = normalized.lower().rfind(needle)
    if idx == -1:
        return None
    return normalized[idx + len(needle):]


def relative_svg_path(path):
    """Map one absolute SVG path to a relative name, or return it unchanged."""
    tail = _directory_tail(path, 'svg')
    if tail is not None:
        return tail
    tail = _directory_tail(path, 'simbolos')
    if tail is not None:
        return 'simbolos/' + tail
    return path


def normalize_svg_paths(text):
    """Rewrite absolute SVG paths in ``text``. Relative paths are left as they are."""
    return _ABS_SVG.sub(lambda match: relative_svg_path(match.group(1)), text)


def main(argv):
    if len(argv) != 2:
        print('Usage: normalize_style_svg_paths.py FILE', file=sys.stderr)
        return 1
    path = argv[1]
    with open(path, encoding='utf-8', newline='') as handle:
        original = handle.read()
    normalized = normalize_svg_paths(original)
    if normalized != original:
        with open(path, 'w', encoding='utf-8', newline='') as handle:
            handle.write(normalized)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
