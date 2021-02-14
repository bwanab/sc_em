defmodule Modsynth.Rand do
  @pent_intervals [0, 3, 5, 7, 10]
  @blues_intervals [0, 3, 5, 6, 7, 10]
  @major_intervals [0, 2, 4, 5, 7, 9, 11]

  @midi_notes [{:C, 24}, {:C!, 25}, {:D, 26}, {:D!, 27}, {:E, 28}, {:F, 29}, {:F!, 30},
               {:G, 31}, {:G!, 32}, {:A, 33}, {:A!, 34}, {:B, 35}]

  @midi_notes_map Enum.into(@midi_notes, %{})

  def rotate(scale, by) do
    Enum.drop(scale, by) ++ Enum.take(scale, by)
  end

  def rotate_octave([f|rest], by) when is_tuple(f) do
    scale = [f|rest]
    Enum.drop(scale, by) ++ Enum.map(Enum.take(scale, by), fn {note, midi} -> {note, midi + 12} end)
  end
  def rotate_octave([f|rest], by) do
    scale = [f|rest]
    Enum.drop(scale, by) ++ Enum.map(Enum.take(scale, by), fn midi -> midi + 12 end)
  end

  def chromatic_scale(key) do
    midi = @midi_notes_map[key]
    cmidi = @midi_notes_map[:C]
    interval = midi - cmidi
    rotate_octave(@midi_notes, interval)
  end

  def major_scale(key) do
    chrome_scale = chromatic_scale(key)
    Enum.map(@major_intervals, fn interval -> Enum.at(chrome_scale, interval) end)
  end
  def minor_scale(key) do rotate_octave(major_scale(key), 5) end

  def scale_notes(scale) do
    Enum.map(scale, fn interval -> Enum.at(@midi_notes, interval) end)
  end

  def scale_notes_note(scale) do
    Enum.map(scale_notes(scale), fn {note, _midi} -> note end)
  end

  def scale_notes_midi(scale) do
    Enum.map(scale_notes(scale), fn {_note, midi} -> midi end)
  end

  def rand_pent(val) do
     :rand.normal(val, 12.0)
  end

  def pent_scale(octave, scale) do
    Enum.map(@pent_intervals, fn x -> x + @midi_notes[scale] + (octave * 12) end)
  end

end
