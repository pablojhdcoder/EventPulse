defmodule EventPulseWeb.EventHelpers do
  def status_color("programado"), do: "#ca8a04"
  def status_color("en_directo"), do: "#16a34a"
  def status_color("finalizado"), do: "#6b7280"
  def status_color(_), do: "#000000"
end