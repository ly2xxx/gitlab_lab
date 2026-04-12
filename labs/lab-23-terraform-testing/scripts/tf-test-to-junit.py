#!/usr/bin/env python3
"""
Convert `terraform test -json` JSONL output to JUnit XML.

Usage:
    terraform test -json | python3 scripts/tf-test-to-junit.py > test-results.xml
    python3 scripts/tf-test-to-junit.py test-results.jsonl > test-results.xml

GitLab CI uploads the XML as a test report:
    artifacts:
      reports:
        junit: test-results.xml
"""

import json
import sys
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom import minidom


def parse_jsonl(source):
    events = []
    for line in source:
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            pass
    return events


def build_junit(events):
    # Group run results by test file
    suites: dict[str, list[dict]] = {}

    for event in events:
        etype = event.get("@type", "")
        if etype == "test_run":
            file_key = event.get("test_file", "unknown.tftest.hcl")
            suites.setdefault(file_key, []).append(event)

    testsuites_el = Element("testsuites")

    for file_name, runs in suites.items():
        failures = sum(1 for r in runs if r.get("status") == "fail")
        errors   = sum(1 for r in runs if r.get("status") == "error")

        suite_el = SubElement(testsuites_el, "testsuite")
        suite_el.set("name", file_name)
        suite_el.set("tests", str(len(runs)))
        suite_el.set("failures", str(failures))
        suite_el.set("errors", str(errors))

        for run in runs:
            tc = SubElement(suite_el, "testcase")
            tc.set("name", run.get("run", "unknown"))
            tc.set("classname", file_name)

            status = run.get("status", "")
            if status == "fail":
                fail_el = SubElement(tc, "failure")
                fail_el.set("message", "Test assertion failed")
                fail_el.text = run.get("message", "")
            elif status == "error":
                err_el = SubElement(tc, "error")
                err_el.set("message", "Test execution error")
                err_el.text = run.get("message", "")

    return testsuites_el


def prettify(element):
    raw = tostring(element, encoding="unicode")
    return minidom.parseString(raw).toprettyxml(indent="  ")


def main():
    if len(sys.argv) > 1:
        with open(sys.argv[1]) as fh:
            events = parse_jsonl(fh)
    else:
        events = parse_jsonl(sys.stdin)

    junit_el = build_junit(events)
    print(prettify(junit_el))

    # Exit non-zero if any tests failed (for CI)
    has_failures = any(
        e.get("status") in ("fail", "error")
        for e in events
        if e.get("@type") == "test_run"
    )
    sys.exit(1 if has_failures else 0)


if __name__ == "__main__":
    main()
