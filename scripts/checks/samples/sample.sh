# expect: the head lacks
set -Eeuo pipefail  # strict mode with one more letter and a comment still counts
TMP_DIR=x  # expect: is short for

deeply_nested() {
  for size in 1; do
    if true; then
      while false; do  # expect: 3 blocks inside each other
        :
      done
    fi
  done
}
echo "done"  # expect: past the shared console
cat <<TEXT  # expect: past the shared console
done
TEXT
