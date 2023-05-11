import std/streams

import ../core/audiotypes

# https://en.wikipedia.org/wiki/Au_file_format
proc readAU*(stream: Stream): Sound =
  result
