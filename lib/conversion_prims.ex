defmodule ConversionPrims do
  ##
  ##  conversion primatives
  ##
  def int32(s, i) do
    <<res :: signed-big-integer-32>> = String.slice(s, i..i+3)
    {res, i + 4}
  end

  def int16(s, i) do
    <<res :: signed-big-integer-16>> = String.slice(s, i..i+1)
    {res, i + 2}
  end

  def int8(s, i) do
    <<res :: big-integer-8>> = String.slice(s, i..i)
    {res, i + 1}
  end

  def float32(s, i) do
    <<res :: float-size(32)>> = String.slice(s, i..i+3)
    {res, i + 4}
  end

  @doc """
  read a pascal type string. First byte contains the length of the
  string in bytes.
  """
  def pstring(s, i) do
    {size, n} = int8(s, i)
    {String.slice(s, i+1..i+size), size + n}
  end

end
