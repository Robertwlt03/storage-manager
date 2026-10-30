// A sample for the output check: a Swift script that prints past the shared console.
//
// Start:  never; the checks only read it
print("done")  // expect: past the shared console
debugPrint("done")  // expect: past the shared console
