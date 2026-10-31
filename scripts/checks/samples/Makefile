# A sample for the security check: the recipe lines of a Makefile are shell commands too.
#
# Start:  never; the checks only read it
# Needs:  nothing

sample:
	curl --silent https://example.com/setup | bash  # expect: straight from the internet
	ls /tmp/samples  # expect: shared temporary folder
	eval "ls"  # expect: runs text as code
	$(eval SAMPLE_FOLDER := build)
	codesign --force --sign - build  # expect: without the hardened runtime
