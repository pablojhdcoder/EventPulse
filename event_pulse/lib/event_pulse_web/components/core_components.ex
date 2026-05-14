defmodule EventPulseWeb.CoreComponents do
  @moduledoc """
  Componentes de interfaz reutilizables (Phoenix.Component).

  Se importan automáticamente en LiveView y módulos HTML vía `EventPulseWeb.html_helpers/0`.
  """

  use Phoenix.Component

  use Gettext, backend: EventPulseWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Muestra un mensaje flash (info o error).

  ## Ejemplos

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} title={gettext("¡Error!")} flash={@flash} />
  """
  attr :id, :string, doc: "id opcional del contenedor del flash"
  attr :flash, :map, default: %{}, doc: "mapa de mensajes flash a mostrar"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "tipo para estilo y clave en el flash"
  attr :rest, :global, doc: "atributos HTML adicionales del contenedor"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      style={flash_style(@kind)}
      {@rest}
    >
      <p :if={@title} style="font-weight:600;font-size:0.875rem;margin:0 0 0.25rem;">{@title}</p>
      <p style="font-size:0.875rem;margin:0;">{msg}</p>
      <button type="button" phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")} style="position:absolute;top:0.5rem;right:0.5rem;background:none;border:none;cursor:pointer;font-size:1rem;">
        ×
      </button>
    </div>
    """
  end

  defp flash_style(:info),
    do:
      "position:fixed;top:0.75rem;right:0.75rem;z-index:50;width:20rem;border-radius:0.5rem;padding:0.75rem 2rem 0.75rem 0.75rem;background:#ecfdf5;color:#065f46;border:1px solid #6ee7b7;"

  defp flash_style(:error),
    do:
      "position:fixed;top:0.75rem;right:0.75rem;z-index:50;width:20rem;border-radius:0.5rem;padding:0.75rem 2rem 0.75rem 0.75rem;background:#fff1f2;color:#881337;border:1px solid #fda4af;"

  @doc """
  Agrupa los flashes estándar (info y error). Solo debe usarse desde `Layouts`.
  """
  attr :flash, :map, required: true, doc: "mapa de mensajes flash"
  attr :id, :string, default: "flash-group", doc: "id opcional del contenedor"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title={gettext("¡Correcto!")} flash={@flash} />
      <.flash kind={:error} title={gettext("¡Error!")} flash={@flash} />
    </div>
    """
  end

  @doc """
  Botón con variantes de estilo.
  """
  attr :type, :string, default: "button"
  attr :variant, :string, default: "primary", values: ["primary", "secondary", "outline"]
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "ep-button",
        button_variant_class(@variant),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Contenedor tipo tarjeta.
  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <section class={["ep-card", @class]} {@rest}>
      {render_slot(@inner_block)}
    </section>
    """
  end

  @doc """
  Alerta en línea para mensajes a nivel de formulario.
  """
  attr :kind, :atom, default: :info, values: [:info, :error]
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def alert(assigns) do
    ~H"""
    <div class={["ep-alert", alert_kind_class(@kind), @class]} role="alert" {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Campo de formulario con etiqueta y errores.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any, default: nil
  attr :type, :string, default: "text"
  attr :field, Phoenix.HTML.FormField, doc: "struct de campo, p. ej. @form[:email]"
  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "valor `checked` para casillas"
  attr :prompt, :string, default: nil, doc: "texto inicial para `<select>`"
  attr :options, :list, doc: "opciones para `Phoenix.HTML.Form.options_for_select/2`"
  attr :multiple, :boolean, default: false, doc: "atributo `multiple` en `<select>`"
  attr :class, :string, default: nil

  attr :rest, :global,
    include: ~w(autocomplete cols disabled form list max maxlength min minlength
    pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="ep-field">
      <label :if={@label} class="ep-label" for={@id}>{@label}</label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "ep-input",
          @errors != [] && "ep-input--error",
          @class
        ]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="ep-field">
      <label :if={@label} class="ep-label" for={@id}>{@label}</label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "ep-input",
          @errors != [] && "ep-input--error",
          @class
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Icono Heroicons (nombre con prefijo `hero-`).
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  defp error(assigns) do
    ~H"""
    <p class="ep-field-error phx-no-feedback:hidden">
      {render_slot(@inner_block)}
    </p>
    """
  end

  defp button_variant_class("primary"), do: "ep-button--primary"
  defp button_variant_class("secondary"), do: "ep-button--secondary"
  defp button_variant_class("outline"), do: "ep-button--outline"

  defp alert_kind_class(:info), do: "ep-alert--info"
  defp alert_kind_class(:error), do: "ep-alert--error"

  defp hide(js, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      try do
        String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
      rescue
        e ->
          IO.warn("""
          en `translate_error/1`, la clave :#{key} esperaba un valor interpolable,
          pero se recibió: #{inspect(value)}.

          Las LiveViews deberían exponer los assigns necesarios en `on_mount`.

          Excepción original: #{Exception.message(e)}
          """)

          acc
      end
    end)
  end
end
