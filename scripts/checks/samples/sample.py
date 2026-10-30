# expect: the head lacks
"""A sample for the checks of scripts, without the shared head on purpose."""


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
