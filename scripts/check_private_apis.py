#!/usr/bin/env python3
"""Bounded private-API regression guard, not a compliance proof.

Scans Swift/ObjC/C/C++ source, ignoring comments. Decodes string escapes and
folds literal `+`, parentheses, and literal arrays with `.joined()` or
`.joined(separator: "")`. It does not evaluate variables, interpolation,
macros, arbitrary encodings, or full Swift semantics. Review remains required.
Use --binary FILE [FILE ...] for explicit executable/resource byte scans;
these inspect embedded strings (ASCII/UTF-8 and UTF-16), not runtime behavior.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import re
import sys

SOURCE_SUFFIXES = {'.swift', '.m', '.mm', '.h', '.c', '.cpp'}
SKIP_DIRS = {'.git', '.build', 'build', 'DerivedData'}
DENIED = (
    'UIKeyboardImpl', 'UIPeripheralHost', 'TIPreferencesController',
    'UIKeyboardPreferencesController', 'keyboardScreenReferenceBounds',
    'UIKeyboardDeviceSupportsSplit', 'PKService', '_hostBundleID', '_hostPID',
    '_xpcConnection', 'xpc_connection_copy_bundle_id',
    'com.apple.keyboard', 'com.apple.TextInput',
)
APPLE_SYMBOL = re.compile(r'^(?:_?(?:UI|TI|CF|CG|CA|NS|AV|AX|IO|Sec)[A-Z_]|_?OBJC_(?:CLASS|METACLASS)_\$_|_?xpc_)')


@dataclass
class Token:
    kind: str
    value: str
    line: int


def decode_literal(value: str, hashes: str = '') -> str:
    escape = '\\' + hashes
    pattern = re.compile(re.escape(escape) + r'(u\{[0-9a-fA-F]+\}|u[0-9a-fA-F]{4}|U[0-9a-fA-F]{8}|x[0-9a-fA-F]{2}|.)', re.S)
    def replace(match):
        item = match.group(1)
        try:
            if item.startswith('u{'):
                return chr(int(item[2:-1], 16))
            if item[0] in 'uUx' and len(item) > 1:
                return chr(int(item[1:], 16))
        except (ValueError, OverflowError):
            return match.group(0)
        return {'n': '\n', 'r': '\r', 't': '\t', '0': '\0', '\n': '', '"': '"', '\\': '\\'}.get(item, match.group(0))
    return pattern.sub(replace, value)


def tokenize(source: str) -> list[Token]:
    tokens = []
    i, line = 0, 1
    while i < len(source):
        if source[i].isspace():
            line += source[i] == '\n'
            i += 1
            continue
        if source.startswith('//', i):
            end = source.find('\n', i)
            i = len(source) if end == -1 else end
            continue
        if source.startswith('/*', i):
            depth = 1
            i += 2
            while i < len(source) and depth:
                if source.startswith('/*', i):
                    depth += 1
                    i += 2
                elif source.startswith('*/', i):
                    depth -= 1
                    i += 2
                else:
                    line += source[i] == '\n'
                    i += 1
            if depth:
                raise ValueError('unterminated block comment')
            continue
        opening = re.match(r'(?:@)?(\#*)("""|")', source[i:])
        if opening:
            start_line = line
            hashes, quote = opening.groups()
            i += len(opening.group())
            start = i
            closing = quote + hashes
            while i < len(source):
                if source.startswith('\\' + hashes, i):
                    # Skip the escaped character, including escaped quote delimiters.
                    length = len(hashes) + 2
                    line += source[i:i + length].count('\n')
                    i += length
                elif source.startswith(closing, i):
                    tokens.append(Token('string', decode_literal(source[start:i], hashes), start_line))
                    i += len(closing)
                    break
                else:
                    line += source[i] == '\n'
                    i += 1
            else:
                raise ValueError(f'unterminated string at line {start_line}')
            continue
        # Character literals in C/ObjC must not be parsed as quoted strings.
        if source[i] == "'":
            end = i + 1
            while end < len(source):
                if source[end] == '\\':
                    end += 2
                elif source[end] == "'":
                    end += 1
                    break
                else:
                    end += 1
            tokens.append(Token('character', source[i:end], line))
            line += source[i:end].count('\n')
            i = end
            continue
        word = re.match(r'[A-Za-z_$][A-Za-z0-9_$]*', source[i:])
        value = word.group() if word else source[i]
        tokens.append(Token('identifier' if word else 'punctuation', value, line))
        i += len(value)
    return tokens


def literal_expression(tokens: list[Token], start: int):
    """Return (constant string, end index), or None; bounded literal grammar."""
    def atom(i):
        if i >= len(tokens):
            return None
        token = tokens[i]
        if token.kind == 'string':
            return token.value, i + 1
        if token.value == '(':
            result = expression(i + 1)
            if result and result[1] < len(tokens) and tokens[result[1]].value == ')':
                return result[0], result[1] + 1
        if token.value == '[':
            pieces = []
            i += 1
            while i < len(tokens) and tokens[i].value != ']':
                result = expression(i)
                if not result:
                    return None
                pieces.append(result[0])
                i = result[1]
                if i < len(tokens) and tokens[i].value == ',':
                    i += 1
                elif i >= len(tokens) or tokens[i].value != ']':
                    return None
            if i >= len(tokens):
                return None
            i += 1
            if [t.value for t in tokens[i:i + 3]] != ['.', 'joined', '(']:
                return None
            i += 3
            if i < len(tokens) and tokens[i].value == ')':
                return ''.join(pieces), i + 1
            if [t.value for t in tokens[i:i + 2]] == ['separator', ':']:
                result = expression(i + 2)
                if result and result[0] == '' and result[1] < len(tokens) and tokens[result[1]].value == ')':
                    return ''.join(pieces), result[1] + 1
        return None

    def expression(i):
        result = atom(i)
        if not result:
            return None
        value, i = result
        while i < len(tokens) and tokens[i].value == '+':
            right = atom(i + 1)
            if not right:
                break
            value += right[0]
            i = right[1]
        return value, i
    return expression(start)


def denied_values(value: str):
    return [needle for needle in DENIED if needle.casefold() in value.casefold()]


def source_findings(source: str) -> list[tuple[int, str]]:
    tokens = tokenize(source)
    findings = set()
    for i, token in enumerate(tokens):
        values = [token.value] if token.kind in {'identifier', 'string'} else []
        folded = literal_expression(tokens, i)
        if folded:
            values.append(folded[0])
        for value in values:
            findings.update((token.line, item) for item in denied_values(value))
        if token.value == 'dlsym' and i + 1 < len(tokens) and tokens[i + 1].value == '(':
            depth, j = 1, i + 2
            while j < len(tokens) and depth:
                candidate = literal_expression(tokens, j)
                if candidate and APPLE_SYMBOL.match(candidate[0]):
                    findings.add((tokens[j].line, 'Apple symbol lookup via dlsym: ' + candidate[0]))
                depth += (tokens[j].value == '(') - (tokens[j].value == ')')
                j += 1
    return sorted(findings)


def binary_findings(data: bytes) -> list[str]:
    findings = set()
    for encoding in ('utf-8', 'utf-16-le', 'utf-16-be'):
        # Test known names directly: decoding arbitrary binary as UTF-16 can
        # lose strings at odd offsets or encounter malformed code units.
        for item in DENIED:
            if item.encode(encoding).lower() in data.lower():
                findings.add(item)
    return sorted(findings)


def collect_sources(inputs: list[str]) -> list[Path]:
    files = set()
    for item in inputs:
        if not item.strip():
            raise ValueError('empty source path')
        path = Path(item)
        if not path.exists():
            raise ValueError(f'missing input: {path}')
        if path.is_file():
            if path.suffix.lower() not in SOURCE_SUFFIXES:
                raise ValueError(f'unsupported source input: {path}')
            files.add(path)
        elif path.is_dir():
            import os
            for root, dirs, names in os.walk(path, onerror=lambda error: (_ for _ in ()).throw(error)):
                dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
                for name in names:
                    candidate = Path(root) / name
                    if candidate.suffix.lower() in SOURCE_SUFFIXES:
                        files.add(candidate)
        else:
            raise ValueError(f'invalid input: {path}')
    if inputs and not files:
        raise ValueError('source inputs contain no supported source files')
    return sorted(files)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sources', nargs='*', help='source files or directories')
    parser.add_argument('--binary', nargs='+', default=[], metavar='FILE', help='explicit executable/resource files')
    args = parser.parse_args(argv)
    if not args.sources and not args.binary:
        parser.error('provide source paths or --binary FILE')
    failed = False
    try:
        files = collect_sources(args.sources)
        for path in files:
            source = path.read_text(encoding='utf-8')
            if not source.strip():
                raise ValueError(f'empty source input: {path}')
            for line, item in source_findings(source):
                print(f'{path}:{line}: prohibited identifier: {item}', file=sys.stderr)
                failed = True
        for item in args.binary:
            path = Path(item)
            if not path.is_file():
                raise ValueError(f'binary input must be a file: {path}')
            data = path.read_bytes()
            if not data:
                raise ValueError(f'empty binary input: {path}')
            for finding in binary_findings(data):
                print(f'{path}: prohibited embedded identifier: {finding}', file=sys.stderr)
                failed = True
    except (OSError, UnicodeError, ValueError, RecursionError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        return 2
    if failed:
        return 1
    print(f'OK: checked {len(files)} source files and {len(args.binary)} binary/resource files; no listed identifiers found. This bounded scan is not proof of public-API compliance.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
