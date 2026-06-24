#!/usr/bin/env python3
import argparse
import sys


def version_parts(version: str) -> list[int]:
    try:
        return [int(part) for part in version.split(".")]
    except ValueError:
        raise ValueError(f"Version must contain numeric components: {version}") from None


def compare_versions(left: str, right: str) -> int:
    left_parts = version_parts(left)
    right_parts = version_parts(right)
    length = max(len(left_parts), len(right_parts))
    left_parts += [0] * (length - len(left_parts))
    right_parts += [0] * (length - len(right_parts))

    if left_parts < right_parts:
        return -1
    if left_parts > right_parts:
        return 1
    return 0


def validate_release(current_version: str, current_build: int, version: str, build: int) -> None:
    if compare_versions(version, current_version) > 0 and build <= current_build:
        raise ValueError(
            "Build must increase when releasing a newer version.\n"
            f"Current: {current_version} ({current_build}); requested: {version} ({build})"
        )


def run_self_test() -> None:
    validate_release("1.1.17", 18, "1.1.18", 19)
    validate_release("1.1.17", 18, "1.1.17", 18)
    validate_release("1.1.17", 18, "1.1.16", 20)

    try:
        validate_release("1.1.17", 18, "1.1.18", 18)
    except ValueError:
        pass
    else:
        raise AssertionError("newer version with stale build should fail")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Daily Todos release version/build monotonicity.")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--current-version")
    parser.add_argument("--current-build", type=int)
    parser.add_argument("--version")
    parser.add_argument("--build", type=int)
    args = parser.parse_args()

    if args.self_test:
        run_self_test()
        print("release version guard self-test passed")
        return 0

    required_arguments = {
        "--current-version": args.current_version,
        "--current-build": args.current_build,
        "--version": args.version,
        "--build": args.build,
    }
    missing_arguments = [name for name, value in required_arguments.items() if value is None]
    if missing_arguments:
        parser.error("the following arguments are required: " + ", ".join(missing_arguments))

    try:
        validate_release(args.current_version, args.current_build, args.version, args.build)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
