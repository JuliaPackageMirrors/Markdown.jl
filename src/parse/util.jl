import Base: peek

const whitespace = " \t\r"

"""
Skip any leading whitespace. Returns io.
"""
function skip_whitespace(io::IO; newlines = true)
  while !eof(io) && (peek(io) in whitespace || (newlines && peek(io) == '\n'))
    read(io, Char)
  end
  return io
end

"""
Skip any leading blank lines. Returns the number skipped.
"""
function skip_blank_lines(io::IO)
  start = position(io)
  i = 0
  while !eof(io)
    c = read(io, Char)
    c == '\n' && (start = position(io); i+=1; continue)
    c in whitespace || break
  end
  seek(io, start)
  return i
end

"""
Returns true if the line contains only (and
at least one of) the characters given.
"""
function next_line_contains_only(io::IO, chars::String; allow_whitespace = true,
                                                        eat = false,
                                                        allowempty = false)
  start = position(io)
  l = readline(io) |> chomp
  length(l) == 0 && return allowempty

  result = false
  for c in l
    c in whitespace && (allow_whitespace ? continue : (result = false; break))
    c in chars && (result = true; continue)
    result = false; break
  end
  !(result && eat) && seek(io, start)
  return result
end

function blankline(io::IO)
  !eof(io) && next_line_contains_only(io, "", allow_whitespace = true, allowempty = true)
end

"""
Test if the stream starts with the given string.
`eat` specifies whether to advance on success (true by default).
`padding` specifies whether leading whitespace should be ignored.
"""
function starts_with(stream::IO, s::String; eat = true, padding = false, newlines = true)
  start = position(stream)
  padding && skip_whitespace(stream, newlines = newlines)
  result = true
  for char in s
    !eof(stream) && read(stream, Char) == char ||
      (result = false; break)
  end
  !(result && eat) && seek(stream, start)
  return result
end

function starts_with{T<:String}(stream::IO, ss::Vector{T}; kws...)
  any(s->starts_with(stream, s; kws...), ss)
end

function starts_with(stream::IO, r::Regex; eat = true, padding = false)
  @assert beginswith(r.pattern, "^")
  start = position(stream)
  padding && skip_whitespace(stream)
  line = chomp(readline(stream))
  seek(stream, start)
  m = match(r, line)
  m == nothing && return ""
  eat && @dotimes length(m.match) read(stream, Char)
  return m.match
end

"""
Read the stream until the delimiter is met.
The delimiter is consumed but not included.
"""
function read_until(stream::IO, delimiter::String, newlines = false)
  start = position(stream)
  buffer = IOBuffer()
  while !eof(stream)
    starts_with(stream, delimiter) && return takebuf_string(buffer)
    char = read(stream, Char)
    !newlines && char == '\n' && break
    write(buffer, char)
  end
  seek(stream, start)
  return nothing
end

"""
Parse a symmetrical delimiter which wraps words.
i.e. `*word word*` but not `*word * word`
"""
function parse_inline_wrapper(stream::IO, delimiter::String, no_newlines = true)
  start = position(stream)
  starts_with(stream, delimiter) || return nothing

  buffer = IOBuffer()
  while !eof(stream)
    char = read(stream, Char)
    no_newlines && char == '\n' && break
    if !(char in whitespace) && starts_with(stream, delimiter)
      write(buffer, char)
      return takebuf_string(buffer)
    end
    write(buffer, char)
  end

  seek(stream, start)
  return nothing
end

function show_rest(io::IO)
  start = position(io)
  show(readall(io))
  seek(io, start)
end
