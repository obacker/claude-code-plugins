#!/usr/bin/env python3
"""
Conservative extraction of file-write destinations from a bash command line.

Design contract: FAIL OPEN. Any construct this module cannot confidently
resolve produces no target, and a command with no resolved targets is
allowed by every caller. False denials are worse than the residual gap.

Recognized write constructs:
  - output redirection: >  >>  >|  &>  &>>  (with optional fd prefix)
  - heredoc into a file: cat <<EOF > path   (body stripped before parsing)
  - tee [-a] path...
  - sed -i / --in-place ... path...
  - cp / mv with a destination
  - dd of=path
  - python[3] -c '... open(path, "w") ...'

Deliberately NOT resolved (dropped as ambiguous):
  - any target containing $, backtick, glob, brace, tilde or parens
  - process substitution >( ... )
  - unbalanced quotes anywhere in the command
  - commands longer than MAX_COMMAND_LEN
"""

import os
import re
import shlex

MAX_COMMAND_LEN = 20000

# Redirection operators that create or extend a file.
WRITE_REDIRECTS = {">", ">>", ">|", "&>", "&>>"}

# Redirections to these are not real file writes.
PSEUDO_FILES = {
    "/dev/null", "/dev/stdout", "/dev/stderr", "/dev/tty",
    "/dev/fd/1", "/dev/fd/2",
}

# A target containing any of these cannot be resolved without executing it.
AMBIGUOUS_CHARS = ("$", "`", "*", "?", "[", "]", "{", "}", "(", ")", "~")

# Shell control operators, used to end argument scanning for a simple command.
OPERATORS = {";", "|", "||", "&", "&&", "\n", "(", ")", "{", "}", "<", "<<",
             "<<<", "<&"} | WRITE_REDIRECTS | {">&"}

_HEREDOC_RE = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
_OPEN_RE = re.compile(
    r"""open\(\s*['"]([^'"]+)['"]\s*,\s*['"]([rwaxbt+]+)['"]"""
)


def strip_heredoc_bodies(command):
    """
    Remove heredoc bodies so their contents are never parsed as shell tokens.

    Without this, `cat > f <<EOF` followed by a body line containing `a > b`
    would yield a bogus write target.
    """
    lines = command.split("\n")
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        delims = [m.group(2) for m in _HEREDOC_RE.finditer(line)]
        i += 1
        for delim in delims:
            # Consume body lines until the delimiter line (or end of input).
            while i < len(lines):
                if lines[i].strip() == delim:
                    i += 1
                    break
                i += 1
    return "\n".join(out)


def tokenize(command):
    """
    Tokenize with operators as distinct tokens. Returns None if the command
    cannot be tokenized (unbalanced quotes, etc.) — callers must fail open.
    """
    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        return list(lexer)
    except Exception:
        return None


def is_ambiguous_target(token):
    """True if the token cannot be resolved to a concrete path."""
    if not token:
        return True
    if any(ch in token for ch in AMBIGUOUS_CHARS):
        return True
    return False


def normalize_target(token, cwd=None):
    """
    Resolve a raw token to a repo-relative path, or None if unusable.
    Absolute paths outside cwd are returned as-is.
    """
    if is_ambiguous_target(token):
        return None

    candidate = token.replace("\\", "/")
    if candidate in PSEUDO_FILES or candidate.startswith("/dev/"):
        return None
    if candidate.startswith("/proc/") or candidate.startswith("/sys/"):
        return None

    base = cwd or os.getcwd()
    try:
        if os.path.isabs(candidate):
            absolute = os.path.normpath(candidate)
            relative = os.path.relpath(absolute, base)
            # Only rewrite to relative when it stays inside the project.
            if not relative.startswith(".."):
                return relative.replace("\\", "/")
            return absolute.replace("\\", "/")
        return os.path.normpath(candidate).replace("\\", "/")
    except Exception:
        return None


def _split_segments(tokens):
    """Split a token stream into simple-command segments on control operators."""
    separators = {";", "|", "||", "&", "&&", "(", ")", "{", "}"}
    segments = []
    current = []
    for token in tokens:
        if token in separators:
            if current:
                segments.append(current)
            current = []
        else:
            current.append(token)
    if current:
        segments.append(current)
    return segments


def _redirect_targets(tokens):
    """Targets from redirection operators anywhere in the token stream."""
    targets = []
    for index, token in enumerate(tokens):
        if token in WRITE_REDIRECTS:
            if index + 1 < len(tokens):
                nxt = tokens[index + 1]
                if nxt not in OPERATORS:
                    targets.append(nxt)
    return targets


def _words_until_operator(tokens):
    """Argument words of a simple command, stopping at the first operator."""
    words = []
    for token in tokens:
        if token in OPERATORS:
            break
        words.append(token)
    return words


def _tee_targets(words):
    """tee [-a|--append|-i] FILE..."""
    targets = []
    for word in words[1:]:
        if word.startswith("-"):
            continue
        targets.append(word)
    return targets


def _sed_targets(words):
    """sed -i [-e SCRIPT | -f FILE] ... FILE..."""
    in_place = False
    has_explicit_script = False
    args = []
    skip_next = False

    for word in words[1:]:
        if skip_next:
            skip_next = False
            continue
        if word.startswith("--in-place") or (
            word.startswith("-i") and not word.startswith("--")
        ):
            in_place = True
            continue
        if word in ("-e", "--expression", "-f", "--file"):
            has_explicit_script = True
            skip_next = True
            continue
        if word.startswith("-e") or word.startswith("-f"):
            if word not in ("-e", "-f"):
                has_explicit_script = True
                continue
        if word.startswith("-"):
            continue
        args.append(word)

    if not in_place:
        return []
    if has_explicit_script:
        return args
    # First positional is the sed script; the rest are files.
    return args[1:] if len(args) > 1 else []


def _cp_mv_targets(words, cwd=None):
    """cp/mv SRC... DEST — destination is the last positional argument."""
    args = [w for w in words[1:] if not w.startswith("-")]
    if len(args) < 2:
        return []

    dest = args[-1]
    sources = args[:-1]

    if is_ambiguous_target(dest):
        return []

    base = cwd or os.getcwd()
    dest_path = dest if os.path.isabs(dest) else os.path.join(base, dest)

    try:
        dest_is_dir = os.path.isdir(dest_path)
    except Exception:
        return []

    if dest_is_dir:
        expanded = []
        for src in sources:
            if is_ambiguous_target(src):
                continue
            expanded.append(os.path.join(dest, os.path.basename(src)))
        return expanded

    if len(sources) == 1:
        return [dest]

    # Multiple sources but the destination is not an existing directory:
    # cannot resolve what gets written where.
    return []


def _dd_targets(words):
    """dd ... of=PATH"""
    targets = []
    for word in words[1:]:
        if word.startswith("of="):
            value = word[3:]
            if value:
                targets.append(value)
    return targets


def _python_c_targets(words):
    """python[3] -c 'CODE' — paths opened for write inside CODE."""
    targets = []
    for index, word in enumerate(words):
        if word == "-c" and index + 1 < len(words):
            code = words[index + 1]
            for match in _OPEN_RE.finditer(code):
                path, mode = match.group(1), match.group(2)
                if any(flag in mode for flag in ("w", "a", "x", "+")):
                    targets.append(path)
    return targets


def extract_write_targets(command, cwd=None):
    """
    Return the list of repo-relative paths this command would confidently
    write to. Unparseable or ambiguous constructs contribute nothing.
    """
    if not command or not isinstance(command, str):
        return []
    if len(command) > MAX_COMMAND_LEN:
        return []
    # Process substitution: the parenthesized body is a separate command
    # whose redirections cannot be attributed. Fail open on the whole line.
    if ">(" in command or "<(" in command:
        return []

    stripped = strip_heredoc_bodies(command)
    tokens = tokenize(stripped)
    if tokens is None:
        return []

    raw_targets = []
    for segment in _split_segments(tokens):
        if not segment:
            continue

        raw_targets.extend(_redirect_targets(segment))

        words = _words_until_operator(segment)
        if not words:
            continue

        name = os.path.basename(words[0])
        if name == "tee":
            raw_targets.extend(_tee_targets(words))
        elif name == "sed":
            raw_targets.extend(_sed_targets(words))
        elif name in ("cp", "mv"):
            raw_targets.extend(_cp_mv_targets(words, cwd=cwd))
        elif name == "dd":
            raw_targets.extend(_dd_targets(words))
        elif name in ("python", "python3", "python2") or name.startswith("python3."):
            raw_targets.extend(_python_c_targets(words))

    resolved = []
    for raw in raw_targets:
        target = normalize_target(raw, cwd=cwd)
        if target and target not in resolved:
            resolved.append(target)
    return resolved
