# ForeverGuide - runs tests/run_tests.lua in the Lua 5.1 runtime bundled with Python's `lupa`
# package, for machines without a lua5.1 binary. Run from the repository root:
#     python -m pip install lupa
#     python tests/run_with_lupa.py
# Copyright (C) 2026 GREYsaurus (https://github.com/GREYsaurus)
# SPDX-License-Identifier: GPL-3.0-only
import lupa.lua51 as lua51

lua51.LuaRuntime().execute('dofile("tests/run_tests.lua")')
