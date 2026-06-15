// Copyright (C) 2026 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

// Text/data utilities used by the network test harness to parse and tally the
// captured monitor output.

// Returns the start index of every non-overlapping occurrence of $needle.
all-indices-of haystack/string needle/string -> List:
  result := []
  from := 0
  while true:
    i := haystack.index-of needle from
    if i < 0: break
    result.add i
    from = i + needle.size
  return result

count-occurrences haystack/string needle/string -> int:
  return (all-indices-of haystack needle).size

// Parses, in order, the integer that follows each occurrence of $prefix in
// $text's lines (e.g. "JNET-F:" -> [0, 1, 2, ...]).
extract-indices text/string prefix/string -> List:
  result := []
  (text.split "\n").do: | line |
    i := line.index-of prefix
    if i >= 0:
      j := i + prefix.size
      k := j
      while k < line.size and '0' <= line[k] <= '9': k++
      if k > j: result.add (int.parse line[j..k])
  return result

// Returns the suffix of $nums beginning at the last occurrence of 0. A container
// numbers its output from zero, so this drops any stale prefix left in the
// device buffer by an earlier run and keeps only the most recent run.
fresh-run nums/List -> List:
  last-zero := 0
  nums.size.repeat: if nums[it] == 0: last-zero = it
  return nums[last-zero..]
