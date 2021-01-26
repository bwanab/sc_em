defmodule ConversionPrims do
  ##
  ##  conversion primatives
  ##
  def int32(s, i) do
    [a, b, c, d] = Enum.slice(s, i, 4)
    <<res :: signed-big-integer-32>> = <<a, b, c, d>>
    {res, i + 4}
  end

  def int24(s, i) do
    [a, b, c] = Enum.slice(s, i, 3)
    <<res :: signed-big-integer-24>> = <<a, b, c>>
    {res, i + 3}
  end

  def int16(s, i) do
    [a, b] = Enum.slice(s, i, 2)
    <<res :: signed-big-integer-16>> = <<a, b>>
    {res, i + 2}
  end

  def int8(s, i) do
    [a] = Enum.slice(s, i, 1)
    <<res :: big-integer-8>> = <<a>>
    {res, i + 1}
  end

  def int8_signed(s, i) do
    [a] = Enum.slice(s, i, 1)
    <<res :: signed-big-integer-8>> = <<a>>
    {res, i + 1}
  end

  def float32(s, i) do
    [a, b, c, d] = Enum.slice(s, i, 4)
    <<res :: float-size(32)>> = <<a, b, c, d>>
    {res, i + 4}
  end

  @doc """
  read a pascal type string. First byte contains the length of the
  string in bytes.
  """
  def pstring(s, i) do
    {size, n} = int8(s, i)
    {List.to_string(Enum.slice(s, n, size)), size + n}
  end

  @doc """
  Takes a string type <<x, y, z>> where one or more of the values isn't a valid char (i.e. over 127)
  and converts it to a list of string representations of the integer in the given base. Defaults to hex.
  """
  def stol(<<fst, rest::binary>>, base \\ 16) do
    [Integer.to_string(fst, base)] ++ if String.length(rest) > 0 do stol(rest, base) else [] end
  end

  @doc """
  Takes a string type <<x, y, z>>, converts to a list of integers [x, y, z]
  """
  def stolist(d) do
    :binary.bin_to_list(d)
  end
end
