defmodule OSC do
  require Logger
  use Bitwise

  defp find0(cl, c, r) do
    <<f::binary-size(1), l::binary>> = cl
    if f == c do
      r
    else
      find0(l, c, [f | r])
    end
  end

  defp find(s, c) do
    String.reverse(List.to_string(find0(s, c, [])))
  end

  defp read_string(s) do
    res = find(s, <<0>>)
    length = String.length(res)
    new_index = ceil((length+1) / 4.0) * 4
    #Logger.info("new_index = #{new_index}")
    {res, String.slice(s, new_index..-1)}
  end

  def read_int(s) do
    length = String.length(s)
    if length < 4 do
      Logger.info("Error: too few bytes for int #{s} #{length}")
      {0, <<>>}
    else
      bin = String.slice(s, 0..3)
      # Logger.debug("bin = #{inspect(bin)}")
      <<res :: big-integer-32>> = bin
      {res, String.slice(s, 4..-1)}
    end
  end

  def read_double(s) do
    length = String.length(s)
    if length < 8 do
      Logger.info("Error: too few bytes for double #{s} #{length}")
      {0.0, <<>>}
    else
      bin = String.slice(s, 0..7)
      <<res :: float>> = bin
      {res, String.slice(s, 8..-1)}
    end
  end

  def read_float(s) do
    length = String.length(s)
    if length < 4 do
      Logger.info("Error: too few bytes for double #{s} #{length}")
      {0.0, <<>>}
    else
      bin = String.slice(s, 0..3)
      # Logger.debug("bin = #{inspect(bin)}")
      <<res :: float-size(32)>> = bin
      {res, String.slice(s, 4..-1)}
    end
  end

  defp read_vals(tags, data, res) do
    #Logger.info("tags = #{tags} res = #{inspect(res)}")
    [h|l] = tags
    {val, r_data} =
      case h do
        115 -> read_string(data)
        105 -> read_int(data)
        102 -> read_float(data)
        _ -> read_double(data)
      end
    if length(l) > 0 do
      read_vals(l, r_data, [val|res])
    else
      Enum.reverse([val|res])
    end
  end

  def decode(s) do
    {addr, rest} = read_string(s)
    {tags, data} = read_string(rest)
    {addr, read_vals(String.to_charlist(String.slice(tags, 1..-1)), data, [])}
  end
end
