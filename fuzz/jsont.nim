import json, posix, fuzzlib, collections

proc main() =
  try:
    let data = stdin.readAll
    discard parseJson(data)
  except ValueError:
    discard
  except OverflowError:
    discard
  except JsonParsingError:
    discard

runFuzz()
