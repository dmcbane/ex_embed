defmodule Mix.Tasks.ExEmbed.List do
  @shortdoc "List all registered embedding models"
  @moduledoc """
  Prints all models in the ExEmbed registry with their dimensions and sizes.

      mix ex_embed.list
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    models = ExEmbed.Registry.all() |> Enum.sort_by(& &1.name)

    Mix.shell().info("\nRegistered ExEmbed models:\n")
    Mix.shell().info(String.pad_trailing("Name", 48) <> String.pad_leading("Dim", 6) <> String.pad_leading("Size(GB)", 10))
    Mix.shell().info(String.duplicate("─", 66))

    Enum.each(models, fn m ->
      Mix.shell().info(
        String.pad_trailing(m.name, 48) <>
          String.pad_leading(to_string(m.dim), 6) <>
          String.pad_leading(to_string(m.size_gb), 10)
      )
    end)

    Mix.shell().info("")
  end
end
