"""The house rules and design rules from CODE_STYLE.md, checked line by line in the Swift code.

Start:  imported by scripts/check.py, not started on its own
Needs:  nothing beyond Python
Most rules are a pattern that must not appear, listed in a table; the few that need more than a
pattern (line length, numbers, German text, short names) are small functions below the tables.
"""

import re
from dataclasses import dataclass
from pathlib import Path

from checks.project import (
    LINE_LENGTH, lines_of, place, relative_path, swift_scripts, swift_sources, swift_tests,
)

# MARK: Settings

TESTS = "Tests/"
DESIGN_SYSTEM = "Sources/DesignSystem/"
DIAGNOSTICS = "Sources/Diagnostics/"
THEME = "Sources/DesignSystem/Theme.swift"
TOKENS = "Sources/DesignSystem/Tokens.swift"
MOTION = "Sources/DesignSystem/Motion.swift"
DEMO_DATA = "Sources/Diagnostics/DemoData.swift"  # made-up content, like test values

ALLOWED_SHORT_NAMES = {"id", "x", "y", "_"}
NUMBERS_THAT_NEED_NO_NAME = {"0", "1"}
DEBUG_MARK = "// DBG"  # ends a temporary line while debugging; it must never be committed


# MARK: Patterns

# Each pattern is written over several lines with a comment per part (re.VERBOSE ignores the
# spaces), so it reads like the rule it stands for.

STRING_LITERAL = re.compile(r'''
    "                   # opening quote
    (?: \\. | [^"\\] )* # escaped characters or anything but a quote
    "                   # closing quote
''', re.VERBOSE)
INTERPOLATION = re.compile(r"\\\( (.*?) \)", re.VERBOSE)  # \(value) inside a string
NUMBER = re.compile(r"""
    (?<! [\w.] )        # not the end of a name or of a longer number
    \d [\d_]*           # digits, maybe grouped like 100_000
    (?: \.\d+ )?        # an optional fraction
    (?! [\w.] )         # nothing glued on after it
""", re.VERBOSE)
NAMED_CONSTANT = re.compile(r"""
    ^ \s*
    (?: @\w+ \s+ )*                                                 # attributes such as @State
    (?: (?: private | fileprivate | static | nonisolated ) \s+ )*   # modifiers
    (?: let | var | case ) \s+ \w+                                  # the name the number gets
""", re.VERBOSE)
AVAILABILITY = re.compile(r"[#@]available \s* \(", re.VERBOSE)  # only takes written versions
SHORT_CLOSURE_PARAMETERS = re.compile(r"""
    \{ \s* \(? \s*                          # a closure's opening brace, maybe a bracket
    ( \w{1,2} (?: \s* , \s* \w{1,2} )* )    # names of one or two letters
    \s* \)? \s+ in \b                       # and then `in`
""", re.VERBOSE)
SHORT_DECLARATION = re.compile(r"""
    \b (?: let | var ) \s+ ( \w{1,2} ) \b   # let a = …
    | \b _ \s+ ( \w{1,2} ) \s* :            # a parameter without a label: _ a: Int
""", re.VERBOSE)
GERMAN_LETTER = re.compile("[äöüÄÖÜß]")

COLOR = re.compile(r"""
    \b (?: Color | NSColor ) \s* [.(]       # Color(…), Color.red, NSColor.…
    | \. (?: red | orange | yellow | green | mint | teal | cyan | blue | indigo | purple
           | pink | brown | gray | black | white ) \b    # a system color such as .red
""", re.VERBOSE)
CLOSURE_SHORTHAND = re.compile(r"\$\d")  # $0, $1 instead of a named closure parameter
DEBUG_LINE = re.compile(re.escape(DEBUG_MARK) + r"\s*$")
FONT = re.compile(r"\.font\(")
SYMBOL_NAME = re.compile(r'''
    systemName: \s* "                       # Image(systemName: "…")
    | \.symbol\( "                          # .symbol("…")
    | " [a-z][a-z0-9]* (?: \.[a-z0-9]+ )+ " # a text shaped like a symbol: "folder.fill"
''', re.VERBOSE)
NOT_A_SYMBOL = re.compile(r'''
    " (?: com | org | net | io ) \.                         # a bundle identifier: "com.…"
    | " \w+ \. (?: app | lproj | strings | png | plist ) "  # a file name: "icon.png"
''', re.VERBOSE)
ANIMATION = re.compile(r"""
    (?: \b withAnimation | \.animation ) \(                 # withAnimation(…), .animation(…)
    | \. (?: smooth | spring | bouncy | snappy | easeInOut ) \b   # a built-in curve
    | \.linear\(
""", re.VERBOSE)
MOTION_TOKEN = re.compile(r"\bMotion\.")
WRITTEN_TEXT = re.compile(r'''
    \b (?: Text | Button | Label | Toggle | Picker | Section ) \( "[^"]   # Text("Hello")
    | \.help\( "[^"]                                                      # .help("Hello")
''', re.VERBOSE)
OUTPUT = re.compile(r"\bprint\(")
OWN_SURFACE = re.compile(r"""
    \.glassEffect\( | \.buttonStyle\( | Material \b
    | \.background\( (?! Backdrop\(\)\) )   # any background but the shared Backdrop()
""", re.VERBOSE)


# MARK: Rule tables


@dataclass(frozen=True)
class SourceLine:
    path: str  # relative to the project, such as "Sources/App/AppEntry.swift"
    place: str
    text: str  # as written
    code: str  # without comments, and texts reduced to the values they show


@dataclass(frozen=True)
class PatternRule:
    """A pattern that must not appear in a line, except in the listed places."""

    message: str
    pattern: re.Pattern
    allowed_in: tuple[str, ...] = ()  # paths that start like this may use it
    reads_comments_and_texts: bool = False  # by default only the code is searched
    fine_when: re.Pattern | None = None  # a line that also matches this keeps the rule

    def is_broken_by(self, line: SourceLine) -> bool:
        searched = line.text if self.reads_comments_and_texts else line.code
        return (
            not line.path.startswith(self.allowed_in)
            and self.pattern.search(searched) is not None
            and not (self.fine_when and self.fine_when.search(searched))
        )


HOUSE_RULES = [
    PatternRule("color defined outside Theme.swift", COLOR, allowed_in=(TESTS, THEME)),
    PatternRule("$0 instead of a named closure parameter", CLOSURE_SHORTHAND),
    PatternRule(
        "temporary debug line left in the code", DEBUG_LINE, reads_comments_and_texts=True),
]

DESIGN_RULES = [
    PatternRule("font set directly, use .textRole(...)", FONT, allowed_in=(DESIGN_SYSTEM,)),
    PatternRule(
        "symbol name outside Symbols in Tokens.swift", SYMBOL_NAME, allowed_in=(TOKENS,),
        reads_comments_and_texts=True, fine_when=NOT_A_SYMBOL),
    PatternRule(
        "animation outside Motion.swift", ANIMATION, allowed_in=(MOTION,), fine_when=MOTION_TOKEN),
    PatternRule(
        "written-out text on screen, use TextKey", WRITTEN_TEXT, reads_comments_and_texts=True),
    PatternRule(
        "own glass, material or background, use .surface()", OWN_SURFACE,
        allowed_in=(DESIGN_SYSTEM,)),
    PatternRule(
        "output outside Diagnostics could show private names", OUTPUT, allowed_in=(DIAGNOSTICS,)),
]


# MARK: Steps


def rule_findings() -> list[str]:
    findings = []
    for line in source_lines(swift_sources() + swift_tests() + swift_scripts()):
        findings += broken_rules(line, HOUSE_RULES)
        findings += [f"{line.place}: {problem}" for problem in special_rule_problems(line)]
    return findings


def design_findings() -> list[str]:
    findings = []
    for line in source_lines(swift_sources()):
        findings += broken_rules(line, DESIGN_RULES)
    return findings


def broken_rules(line: SourceLine, rules: list[PatternRule]) -> list[str]:
    return [f"{line.place}: {rule.message}" for rule in rules if rule.is_broken_by(line)]


def special_rule_problems(line: SourceLine) -> list[str]:
    """The rules that need more than one pattern."""
    problems = []
    if len(line.text) > LINE_LENGTH:
        problems.append(f"line longer than {LINE_LENGTH} characters")
    if not line.path.startswith((TESTS, DEMO_DATA)):  # tests may use plain example values
        problems += [f"number {number} has no name" for number in numbers_without_name(line.code)]
    if any(GERMAN_LETTER.search(text) for text in string_literals(line.text)):
        problems.append("German text in code, it belongs in the translations")
    problems += [f"short name '{name}'" for name in short_names(line.code)]
    return problems


# MARK: Reading Swift lines


def source_lines(paths: list[Path]):
    for path in paths:
        for number, text in enumerate(lines_of(path), start=1):
            yield SourceLine(relative_path(path), place(path, number), text, bare_code(text))


def bare_code(text: str) -> str:
    """The line without its comment; a text keeps only the values it shows: "\\(count) files"
    becomes "count", so a number or name inside a text still counts as code."""
    def interpolated_values(literal: re.Match) -> str:
        return " ".join(INTERPOLATION.findall(literal.group(0)))

    return STRING_LITERAL.sub(interpolated_values, text).split("//", 1)[0]


def string_literals(text: str) -> list[str]:
    code_part = text.split("//", 1)[0]
    searched = text if '"' in code_part else code_part  # "//" inside a text is no comment
    return [literal.strip('"') for literal in STRING_LITERAL.findall(searched)]


def numbers_without_name(code: str) -> list[str]:
    if NAMED_CONSTANT.match(code) or AVAILABILITY.search(code):
        return []
    numbers = NUMBER.findall(code)
    return [
        number for number in numbers if number.replace("_", "") not in NUMBERS_THAT_NEED_NO_NAME
    ]


def short_names(code: str) -> list[str]:
    names = [
        name.strip()
        for match in SHORT_CLOSURE_PARAMETERS.finditer(code)
        for name in match.group(1).split(",")
    ]
    names += [match.group(1) or match.group(2) for match in SHORT_DECLARATION.finditer(code)]
    return [name for name in names if name not in ALLOWED_SHORT_NAMES]
