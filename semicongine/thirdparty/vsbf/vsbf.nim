## This is a very simple binary format, aimed at game save serialisation.
## By using type information encoded we can catch decode errors and optionally invoke converters
## Say data was saved as a `Float32` but now is an `Int32` we can know this and do `int32(floatVal)`

import vsbf/[shared, decoders, encoders]
export skipSerialization, decoders, encoders
