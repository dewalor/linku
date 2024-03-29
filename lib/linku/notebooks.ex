defmodule Linku.Notebooks do
  @moduledoc """
  The Notebooks context.
  """

  import Ecto.Query, warn: false
  alias Linku.{Repo, Scope, Events}

  alias Linku.Notebooks.{Renku, Line, RenkuNotifier}
  alias Linku.Collaborations
  alias Linku.Collaborations.Invitation
  alias Linku.ActivityLog

  @doc """
  Subscribers the given scope to the line pubsub.

  For logged in users, this will be a topic scoped only to the logged in user.
  If the system is extended to allow shared renkus, the topic subscription could
  be derived for a particular organizatoin or team, particlar renku, and so on.
  """
  def subscribe(%Scope{} = scope) do
    Phoenix.PubSub.subscribe(Linku.PubSub, topic(scope))
  end

  @doc """
  Reorders a renku in the current users board.

  Broadcasts `%Events.RenkuRepositioned{}` on the scoped topic when successful.
  """
  def update_renku_position(%Scope{} = scope, %Renku{} = renku, new_index) do
    Ecto.Multi.new()
    |> multi_reposition(:new, renku, renku, new_index, user_id: scope.current_user.id)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        new_renku = %Renku{renku | position: new_index}

        log =
          ActivityLog.log(scope, renku, %{
            action: "renku_position_updated",
            subject_text: renku.title,
            before_text: renku.position,
            after_text: new_index
          })

        broadcast(scope, %Events.RenkuRepositioned{renku: new_renku, log: log})

        :ok

      {:error, _failed_op, failed_val, _changes_so_far} ->
        {:error, failed_val}
    end
  end

  @doc """
  Updates the position of a line in the renku it belongs to.

  Broadcasts %Events.LineRepositioned{} on the scoped topic.
  """
  def update_line_position(%Scope{} = scope, %Line{} = line, new_index) do
    Ecto.Multi.new()
    |> multi_reposition(:new, line, {Renku, line.renku_id}, new_index, renku_id: line.renku_id)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        new_line = %Line{line | position: new_index}

        log =
          ActivityLog.log(scope, line, %{
            action: "line_position_updated",
            subject_text: line.title,
            before_text: line.position,
            after_text: new_index
          })

        broadcast(scope, %Events.LineRepositioned{line: new_line, log: log})

        :ok

      {:error, _failed_op, failed_val, _changes_so_far} ->
        {:error, failed_val}
    end
  end

  def change_line(line_or_changeset, attrs \\ %{}) do
    Line.changeset(line_or_changeset, attrs)
  end

  @doc """
  Moves a line from one renku to another.

  Broadcasts %Events.LineDeleted{} on the scoped topic for the old renku.
  Broadcasts %Events.LineRepositioned{} on the scoped topic for the new renku.
  """
  def move_line_to_renku(%Scope{} = scope, %Line{} = line, %Renku{} = renku, at_index) do
    Ecto.Multi.new()
    |> Repo.multi_transaction_lock(:old_renku, {Renku, line.renku_id})
    |> Repo.multi_transaction_lock(:new_renku, renku)
    |> multi_update_all(:dec_positions, fn _ ->
      from(t in Line,
        where: t.renku_id == ^line.renku_id,
        where:
          t.position > subquery(from og in Line, where: og.id == ^line.id, select: og.position),
        update: [inc: [position: -1]]
      )
    end)
    |> Ecto.Multi.run(:pos_at_end, fn repo, _changes ->
      position = repo.one(from t in Line, where: t.renku_id == ^renku.id, select: count(t.id))
      {:ok, position}
    end)
    |> multi_update_all(:move_to_renku, fn %{pos_at_end: pos_at_end} ->
      from(t in Line,
        where: t.id == ^line.id,
        update: [set: [renku_id: ^renku.id, position: ^pos_at_end]]
      )
    end)
    |> multi_reposition(:new, line, renku, at_index, renku_id: renku.id)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        new_line = %Line{line | renku: renku, renku_id: renku.id, position: at_index}

        log =
          ActivityLog.log(scope, new_line, %{
            action: "line_moved",
            subject_text: new_line.title,
            before_text: line.renku.title,
            after_text: renku.title
          })

        broadcast(scope, %Events.LineDeleted{line: line})
        broadcast(scope, %Events.LineRepositioned{line: new_line, log: log})

        :ok

      {:error, _failed_op, failed_val, _changes_so_far} ->
        {:error, failed_val}
    end
  end

  @doc """
  Deletes a line for the current scope.

  Broadcasts %Events.LineDeleted{} on the scoped topic when successful.
  """
  def delete_line(%Scope{} = scope, %Line{} = line) do
    Ecto.Multi.new()
    |> Repo.multi_transaction_lock(:renku, {Renku, line.renku_id})
    |> multi_decrement_positions(:dec_rest_in_renku, line, renku_id: line.renku_id)
    |> Ecto.Multi.delete(:line, line)
    |> Repo.transaction()
    |> case do
      {:ok, %{line: line}} ->
        log =
          ActivityLog.log(scope, line, %{
            action: "line_deleted",
            subject_text: line.title,
            after_text: line.renku.title
          })

        broadcast(scope, %Events.LineDeleted{line: line, log: log})

        {:ok, line}

      {:error, _failed_op, failed_val, _changes_so_far} ->
        {:error, failed_val}
    end
  end

  def get_line!(%Scope{} = scope, id) do
    from(t in Line, where: t.id == ^id and t.user_id == ^scope.current_user.id)
    |> Repo.one!()
    |> Repo.preload(:renku)
  end

  @doc """
  Updates a line for the current scope.

  Broadcasts %Events.LineUpdated{} on the scoped topic when successful.
  """
  def update_line(%Scope{} = scope, %Line{} = line, params) do
    line
    |> Line.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, new_line} ->
        log =
          if line.title != new_line.title do
            ActivityLog.log(scope, new_line, %{
              action: "line_updated",
              subject_text: line.title,
              after_text: new_line.title
            })
          end

        broadcast(scope, %Events.LineUpdated{line: new_line, log: log})

        {:ok, new_line}

      other ->
        other
    end
  end

  def line_count_for_renku(renku) do
    query = from l in Line, select: count(l.id), where: l.renku_id==^renku.id

    query
      |> Repo.all()
      |> List.first()
  end

  @doc """
  Creates a line for the current scope.

  Broadcasts %Events.LineAdded{} on the scoped topic when successful.
  """
  def create_line(%Scope{current_user: current_user} = scope, %Renku{} = renku, params) do
    line = %Line{
      user_id: scope.current_user.id,
      status: :started,
      renku_id: renku.id
    }

    Ecto.Multi.new()
    |> Repo.multi_transaction_lock(:renku, renku)
    |> update_invitation_if_any(renku, current_user)
    |> Ecto.Multi.run(:position, fn repo, _changes ->
      position = repo.one(from l in Line, where: l.renku_id == ^renku.id, select: count(l.id))

      {:ok, position}
    end)
    |> Ecto.Multi.insert(:line, fn %{position: position} ->
      Line.changeset(%Line{line | position: position}, params)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{line: line}} ->
        log =
          ActivityLog.log(scope, line, %{
            action: "line_created",
            subject_text: line.title,
            after_text: renku.title
          })

        broadcast(scope, %Events.LineAdded{line: line, log: log})
        line = Repo.preload(line, :user)
        renku = Repo.preload(renku, :user)
        RenkuNotifier.deliver_renku_completion_notification(renku.user, line.user, renku)

        {:ok, line}

      {:error, :line, changeset, _changes_so_far} ->
        {:error, changeset}
    end
  end

  @doc """
  Returns the active renkus for the current scope.
  """
  def active_renkus(%Scope{} = scope, limit) do
    # active_renkus_query should return:
    # 1. renkus the current user initiated, if any AND
    # 2. renkus with lines they were invited to read

    line_invitee_subset =
      from(
        i in Invitation,
        where: i.invitee_email == ^scope.current_user.email
      )

    renku_invitee_query =
      from(r in Renku,
        join: l in Line,
        on: l.renku_id == r.id,
        join: s in subquery(line_invitee_subset),
        on: s.line_id == l.id
      )

    renku_query =
      from(r in Renku,
        where: r.user_id == ^scope.current_user.id,
        union: ^renku_invitee_query,
        limit: ^limit
      )

    # active_renkus_query should return the above renkus with these lines preloaded:
    # 1. if the current user initiated any renkus, they should see all the lines in those renkus AND
    # 2. if the current user was invited to any renkus, they should see all the lines they were invited to read in those renkus AND the lines they wrote

    renku_initiator_query =
      from(l in Line,
        join: r in Renku,
        on: l.renku_id == r.id,
        where: r.user_id == ^scope.current_user.id
      )

    invitee_query =
      from(l in Line,
        join: i in Invitation,
        on: i.line_id == l.id,
        where: i.invitee_email == ^scope.current_user.email
      )

    lines_query =
      from(
        l in Line,
        where: l.user_id == ^scope.current_user.id,
        union: ^renku_initiator_query,
        union: ^invitee_query
      )

    renku_query
      |> Repo.all()
      |> Repo.preload([lines: {(from s in subquery(lines_query), order_by: s.id), :invitations}])
  end

  @doc """
    returns a list of published renkus
  """
  def published_renkus() do
    renku_query =
      from r in Renku,
        where: not is_nil(r.published_at),
        order_by: [asc: :position]

    renku_query
      |> Repo.all()
      |> Repo.preload(:lines)
  end

  @doc """
  Gets renkus owned by the scoped user.

  Raises `Ecto.NoResultsError` if the Renku does not exist.
  """
  def get_renkus_for_user!(%Scope{} = scope) do
    from(r in Renku, where: r.user_id == ^scope.current_user.id)
    |> Repo.all()
    |> preload()
  end

  @doc """
  Gets a single renku owned by the scoped user.

  Raises `Ecto.NoResultsError` if the Renku does not exist.
  """
  def get_renku!(%Scope{} = scope, id) do
    from(r in Renku, where: r.user_id == ^scope.current_user.id, where: r.id == ^id)
    |> Repo.one!()
    |> preload()
  end

  @doc """
  Gets renkus owned by the scoped user.
  """
  def get_renkus_for_user(%Scope{} = scope) do
    from(r in Renku, where: r.user_id == ^scope.current_user.id)
    |> Repo.all()
    |> preload()
  end

  @doc """
  Gets a single renku if the scoped user is allowed to add a line to it, i.e. invited to or owns it.

  Raises `Ecto.NoResultsError` if the ownership or invitation association or the given renku does not exist.
  """
  def get_renku_if_allowed_to_write!(id, %Scope{} = scope) do
    line_invitee_subset =
      from(
        i in Invitation,
        where: i.invitee_email == ^scope.current_user.email
      )

    renku_invitee_query =
      from(r in Renku,
        join: l in Line,
        on: l.renku_id == r.id,
        join: s in subquery(line_invitee_subset),
        on: s.line_id == l.id,
        where: r.id == ^id
      )

    renku_query =
      from(r in Renku,
        where: r.id == ^id,
        where: r.user_id == ^scope.current_user.id,
        union: ^renku_invitee_query
      )
    Repo.one!(renku_query)
    |> preload()
  end

  defp preload(resource), do: Repo.preload(resource, [:lines])

  @doc """
  Creates a renku for the current scope.

  Broadcasts `%Events.RenkuAdded{}` on the scoped topic when successful.
  """
  def create_renku(%Scope{} = scope, attrs \\ %{}) do
    Ecto.Multi.new()
    |> Repo.multi_transaction_lock(:user, scope.current_user)
    |> Ecto.Multi.run(:position, fn repo, _changes ->
      position =
        repo.one(from r in Renku, where: r.user_id == ^scope.current_user.id, select: count(r.id))

      {:ok, position}
    end)
    |> Ecto.Multi.insert(:renku, fn %{position: position} ->
      Renku.changeset(%Renku{user_id: scope.current_user.id, position: position}, attrs)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{renku: renku}} ->
        renku = Repo.preload(renku, :lines)

        log =
          ActivityLog.log(scope, renku, %{
            action: "renku_created",
            subject_text: renku.title
          })

        broadcast(scope, %Events.RenkuAdded{renku: renku, log: log})

        {:ok, renku}

      {:error, _failed_op, failed_val, _changes_so_far} ->
        {:error, failed_val}
    end
  end

  @doc """
  Updates a renku.

  Broadcasts %Events.RenkuUpdated{} on the scoped topic when successful.
  """
  def update_renku(%Scope{} = scope, %Renku{} = renku, attrs) do
    renku
    |> Renku.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, new_renku} ->
        log =
          if renku.title != new_renku.title do
            ActivityLog.log(scope, new_renku, %{
              action: "renku_updated",
              subject_text: renku.title,
              after_text: new_renku.title
            })
          end

        broadcast(scope, %Events.RenkuUpdated{renku: new_renku, log: log})

        {:ok, new_renku}

      other ->
        other
    end
  end

  @doc """
  Deletes a renku.

  Broadcasts %Events.RenkuDeleted{} on the scoped topic when successful.
  """
  def delete_renku(%Scope{} = scope, %Renku{} = renku) do
    Ecto.Multi.new()
    |> Repo.multi_transaction_lock(:user, scope.current_user)
    |> multi_decrement_positions(:dec_rest_in_parent, renku, user_id: renku.user_id)
    |> Ecto.Multi.delete(:renku, renku)
    |> Repo.transaction()
    |> case do
      {:ok, %{renku: renku}} ->
        log =
          ActivityLog.log(scope, renku, %{
            action: "renku_deleted",
            subject_text: renku.title
          })

        broadcast(scope, %Events.RenkuDeleted{renku: renku, log: log})

        {:ok, renku}

      {:error, _failed_op, failed_val, _changes_so_far} ->
        {:error, failed_val}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking renku changes.

  ## Examples

      iex> change_renku(renku)
      %Ecto.Changeset{data: %Renku{}}

  """
  def change_renku(%Renku{} = renku, attrs \\ %{}) do
    Renku.changeset(renku, attrs)
  end

  def publish_renku(%Scope{} = scope, %Renku{} = renku) do
    if scope.current_user.id == renku.user_id do
      renku
      |> Renku.publish_changeset()
      |> Repo.update()
      |> case do
        {:ok, new_renku} ->
          log = ActivityLog.log(scope, new_renku, %{
                action: "renku_published",
                subject_text: renku.title
              })


          broadcast(scope, %Events.RenkuPublished{renku: renku, log: log})
          {:ok, new_renku}

        other ->
          other
      end
    end
  end

  defp multi_update_all(multi, name, func, opts \\ []) do
    Ecto.Multi.update_all(multi, name, func, opts)
  end

  defp broadcast(%Scope{} = scope, event) do
    Phoenix.PubSub.broadcast(Linku.PubSub, topic(scope), {__MODULE__, event})
  end

  defp topic(%Scope{} = scope), do: "lines:#{scope.current_user.id}"

  defp multi_reposition(%Ecto.Multi{} = multi, name, %type{} = struct, lock, new_idx, where_query)
      when is_integer(new_idx) do
    old_position = from(og in type, where: og.id == ^struct.id, select: og.position)

    multi
    |> Repo.multi_transaction_lock(name, lock)
    |> Ecto.Multi.run({:index, name}, fn repo, _changes ->
      case repo.one(from(t in type, where: ^where_query, select: count(t.id))) do
        count when new_idx < count -> {:ok, new_idx}
        count -> {:ok, count - 1}
      end
    end)
    |> multi_update_all({:dec_positions, name}, fn %{{:index, ^name} => computed_index} ->
      from(t in type,
        where: ^where_query,
        where: t.id != ^struct.id,
        where: t.position > subquery(old_position) and t.position <= ^computed_index,
        update: [inc: [position: -1]]
      )
    end)
    |> multi_update_all({:inc_positions, name}, fn %{{:index, ^name} => computed_index} ->
      from(t in type,
        where: ^where_query,
        where: t.id != ^struct.id,
        where: t.position < subquery(old_position) and t.position >= ^computed_index,
        update: [inc: [position: 1]]
      )
    end)
    |> multi_update_all({:position, name}, fn %{{:index, ^name} => computed_index} ->
      from(t in type,
        where: t.id == ^struct.id,
        update: [set: [position: ^computed_index]]
      )
    end)
  end

  defp multi_decrement_positions(%Ecto.Multi{} = multi, name, %type{} = struct, where_query) do
    multi_update_all(multi, name, fn _ ->
      from(t in type,
        where: ^where_query,
        where:
          t.position > subquery(from og in type, where: og.id == ^struct.id, select: og.position),
        update: [inc: [position: -1]]
      )
    end)
  end

  defp update_invitation_if_any(multi, renku, current_user) do
      open_invitation_for_renku_query = from i in Invitation,
      join: l in Line,
      on: l.id == i.line_id,
      where: l.renku_id == ^renku.id,
      where: is_nil(i.accepted_at),
      where: i.invitee_email == ^current_user.email

      invitation = Repo.one(open_invitation_for_renku_query)
      cond do
        invitation ->
          invitation_changeset = Collaborations.change_invitation(invitation, %{accepted_at: DateTime.utc_now()})
          Ecto.Multi.update(multi, :invitation, invitation_changeset)
        current_user.id == renku.user_id -> multi
        true -> raise "Current user with id #{current_user.id} should be the initiator of the renku or have exactly one open invitation."

      end
  end

  def test(to, %Scope{} = _scope) do
    parent = self()
    Node.spawn_link(to, fn ->
      send(parent, {:done, node()})
    end)
  end
end
