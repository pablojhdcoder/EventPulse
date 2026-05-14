defmodule EventPulseWeb.ErrorJSONTest do
  use EventPulseWeb.ConnCase, async: true

  test "renderiza 404 en JSON" do
    assert EventPulseWeb.ErrorJSON.render("404.json", %{}) == %{
             errors: %{detail: "No encontrado"}
           }
  end

  test "renderiza 500 en JSON" do
    assert EventPulseWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Error interno del servidor"}}
  end
end
