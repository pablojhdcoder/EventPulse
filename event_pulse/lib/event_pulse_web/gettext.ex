defmodule EventPulseWeb.Gettext do
  @moduledoc """
  Internacionalización (i18n) con Gettext.

  Al usar [Gettext](https://hexdocs.pm/gettext), este módulo compila las cadenas
  traducibles. Para usar este backend:

      use Gettext, backend: EventPulseWeb.Gettext

      # Traducción simple
      gettext("Texto a traducir")

      # Plural
      ngettext("Un elemento",
               "Varios elementos",
               3)

      # Por dominio
      dgettext("errors", "Mensaje de error")

  Más detalle en la [documentación de Gettext](https://hexdocs.pm/gettext).
  """
  use Gettext.Backend, otp_app: :event_pulse
end
