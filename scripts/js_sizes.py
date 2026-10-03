#!/usr/bin/env python3
"""Where the bytes of main.dart.js come from, by package, via its source map.

    flutter build web --release --source-maps
    python3 scripts/js_sizes.py build/web/main.dart.js build/web/main.dart.js.map

Every byte a mapping segment covers is counted against the source file the
segment points at, then grouped by pub package (or the SDK, the engine and the
app's own top-level directories). The bytes no segment covers, constants and
type tables among them, are printed after the total rather than guessed at.
"""
import collections
import json
import re
import sys

B64 = {c: i for i, c in enumerate(
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/')}


def vlq(segment):
    values, shift, value = [], 0, 0
    for char in segment:
        digit = B64[char]
        more, digit = digit & 32, digit & 31
        value += digit << shift
        if more:
            shift += 5
            continue
        values.append(-(value >> 1) if value & 1 else value >> 1)
        shift = value = 0
    return values


def group(source):
    for pattern in (r'pub\.dev/([a-z0-9_]+)-[0-9]', r'packages/([a-z0-9_]+)/'):
        if match := re.search(pattern, source):
            return match.group(1)
    if 'dart-sdk' in source:
        return 'dart-sdk'
    if '/lib/_engine/' in source or 'lib/_engine' in source:
        return 'flutter engine'
    # dart:ui and the engine's other libraries, which the fallback below would
    # count as the app's own.
    if source.startswith('org-dartlang-sdk:///lib/'):
        return 'flutter engine'
    if '/lib/' in source:
        return 'garage: ' + source.split('/lib/')[-1].split('/')[0]
    return 'other'


def main():
    lines = open(sys.argv[1], encoding='utf-8').read().split('\n')
    source_map = json.load(open(sys.argv[2]))
    sources = source_map['sources']
    sizes = collections.Counter()
    source = 0
    for number, mapping in enumerate(source_map['mappings'].split(';')):
        if number >= len(lines):
            break
        column, segments = 0, []
        for segment in filter(None, mapping.split(',')):
            values = vlq(segment)
            column += values[0]
            if len(values) >= 4:
                source += values[1]
                segments.append((column, source))
            else:
                segments.append((column, None))
        for i, (start, index) in enumerate(segments):
            end = segments[i + 1][0] if i + 1 < len(segments) else len(lines[number])
            name = group(sources[index]) if index is not None else 'other'
            sizes[name] += max(0, end - start)
    total = sum(sizes.values())
    for name, size in sizes.most_common(25):
        print(f'{name:40} {size / 1024:8.0f} KB {100 * size / total:5.1f}%')
    print(f'{"total":40} {total / 1024:8.0f} KB')
    unmapped = sum(map(len, lines)) - total
    print(f'{"not in the source map":40} {unmapped / 1024:8.0f} KB')


if __name__ == '__main__':
    main()
