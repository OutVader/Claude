#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Hook PermissionRequest de Claude Code -> JEV. Fail-closed: ante cualquier error, sin salida."""
import os
import sys

try:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import jev

    sys.exit(jev.main(["hook"] + sys.argv[1:]))
except SystemExit:
    raise
except BaseException:
    sys.exit(0)
