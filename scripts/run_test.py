#!/usr/bin/env python3
"""Run a single Lua test file on lupa's Lua 5.1 runtime, matching CI's lua5.1.

Usage:  python scripts/run_test.py tests/core/test_secret.lua
"""

import sys
import os

try:
    # Plain `from lupa import LuaRuntime` picks lupa's newest bundled Lua (5.5),
    # which accepts code that breaks on CI's Lua 5.1.
    from lupa.lua51 import LuaRuntime
except ImportError:
    print("ERROR: lupa with Lua 5.1 is not installed. Run: pip install -U lupa", file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) < 2:
        print("Usage: python scripts/run_test.py <test-file.lua>", file=sys.stderr)
        sys.exit(1)

    test_path = sys.argv[1].replace("\\", "/")
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace("\\", "/")

    lua = LuaRuntime(unpack_returned_tuples=True)

    # Set up package.path to mirror tests/run.lua
    lua.execute(f"""
        package.path = "{project_root}/?.lua;{project_root}/?/init.lua;" .. package.path

        local rawRequire = require
        require = function(name)
            if type(name) == "string" and name:find("LevelUpInfo.", 1, true) == 1 then
                name = name:sub(#"LevelUpInfo." + 1)
            end
            return rawRequire(name)
        end
        _G.require = require
    """)

    # Match tests/run.lua: no WoW globals are pre-installed; each test loads
    # tests/helpers/wow.lua itself.

    abs_test_path = os.path.join(project_root, test_path).replace("\\", "/")
    if not os.path.isfile(abs_test_path):
        print(f"ERROR: test file not found: {abs_test_path}", file=sys.stderr)
        sys.exit(1)

    try:
        test_fn = lua.execute(f'return dofile("{abs_test_path}")')
        if callable(test_fn):
            test_fn()
        print(f"PASS {test_path}")
    except Exception as e:
        print(f"FAIL {test_path}", file=sys.stderr)
        print(str(e), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
