# expect: the head lacks
"""A sample for the checks of scripts, without the shared head on purpose."""

import json  # expect: is imported but never used
import sys

UNUSED_SETTING = 1  # expect: is declared but never used


def probe_msg(arg_count):  # expect: is short for
    return arg_count


def deeply_nested(values):
    total = 0
    for value in values:
        if value:
            if value != 1:  # expect: 3 blocks inside each other
                total += value
    return total


def outer_function():
    def inner_function():
        def innermost_function():  # expect: a function inside a function inside a function
            return 1
        return innermost_function()
    return inner_function()


print("done")  # expect: past the shared console
sys.stdout.write("done")  # expect: past the shared console
probe_msg(deeply_nested([outer_function()]))
