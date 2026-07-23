#!/usr/bin/env python3
"""Merge Gradle's per-class JUnit XML reports into one file.

Gradle writes `build/test-results/testDebugUnitTest/TEST-<class>.xml` — one file
per test class — but codeyam-editor's `junit-xml` runner reads a single
`outputPath`, the way the Swift runner's `--xunit-output` produces one file. With
a directory there, the editor found no parseable results and reported the whole
Android runner as producing no tests, so every Kotlin test was invisible to the
audit gate even while passing.

This collapses the per-class files into one `<testsuites>` document. Both unit
test variants (debug and release) run the same sources, so only `testDebugUnitTest`
is merged — including both would double-count every test.

Usage: merge-test-results.py <results-dir> <output-xml>
"""

import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2

    results_dir = Path(sys.argv[1])
    out_path = Path(sys.argv[2])

    merged = ET.Element("testsuites")
    totals = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0}

    for xml_file in sorted(results_dir.glob("TEST-*.xml")):
        try:
            suite = ET.parse(xml_file).getroot()
        except ET.ParseError as exc:
            print(f"warning: skipping unparseable {xml_file}: {exc}", file=sys.stderr)
            continue
        for key in totals:
            totals[key] += int(suite.get(key, 0) or 0)
        merged.append(suite)

    for key, value in totals.items():
        merged.set(key, str(value))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(merged).write(out_path, encoding="utf-8", xml_declaration=True)

    print(
        f"merged {len(merged)} suite(s) -> {out_path} "
        f"(tests={totals['tests']} failures={totals['failures']} errors={totals['errors']})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
