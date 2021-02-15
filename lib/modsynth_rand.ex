defmodule Modsynth.Rand do
  require Logger
  def closest(note, scale) do
    index = Enum.find_index(scale, fn x -> x > note end)
    if is_nil(index) do
      if note < List.first(scale) do
        List.first(scale)
      else
        List.last(scale)
      end
    else
      val1 = Enum.at(scale, index - 1)
      val2 = Enum.at(scale, index)
      if note - val1 < val2 - note do val1 else val2 end
    end
   end

  def rand(val, scale) do
    :rand.normal(val, 12.0)
    |> closest(scale)
  end

end
