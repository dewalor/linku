defmodule Linku.ActivityLog do
  @moduledoc """
  Defines a basic activity log for decoupled activity streams.

  > This module is *not intended for use as a forensic log* of
  events. It does not provide transactional guarantees and cannot
  be used to recreate state in a system, such as a full event source
  or similar log.
  """
  import Ecto.Query
  alias Linku.ActivityLog
  alias Linku.ActivityLog.Entry
  alias Linku.{Repo, Scope, Notebook}

  def log(%Scope{} = scope, %Notebook.Line{} = line, %{} = attrs) do
    id = if line.__meta__.state == :deleted, do: nil, else: line.id

    %Entry{line_id: id, renku_id: line.renku_id, user_id: scope.current_user_id}
    |> put_performer(scope)
    |> Entry.changeset(attrs)
    |> Repo.insert!()
  end

  def log(%Scope{} = scope, %Notebook.Renku{} = renku, %{} = attrs) do
    id = if renku.__meta__.state == :deleted, do: nil, else: renku.id

    %Entry{renku_id: id, user_id: scope.current_user_id}
    |> put_performer(scope)
    |> Entry.changeset(attrs)
    |> Repo.insert!()
  end

  def list_user_logs(%Scope{} = scope, opts) do
    limit = Keyword.fetch!(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    from(l in ActivityLog.Entry,
      where: l.user_id == ^scope.current_user.id,
      offset: ^offset,
      limit: ^limit,
      order_by: [desc: l.id]
    )
    |> Repo.all()
  end

  defp put_performer(%Entry{} = entry, %Scope{} = scope) do
    %Entry{entry | performer_text: scope.current_user.email}
  end
end
