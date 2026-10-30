# expect: the head lacks
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
