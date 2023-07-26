defmodule Linku.Todos do
  @moduledoc """
  The Todos context.
  """

  import Ecto.Query, warn: false
  alias Linku.{Repo, Scope, Events}

  alias Linku.Todos.{Renku, Todo}
  alias Linku.ActivityLog

  @max_todos 1000

  @doc """
  Subscribers the given scope to the todo pubsub.

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
  Updates the position of a todo in the renku it belongs to.

  Broadcasts %Events.TodoRepositioned{} on the scoped topic.
  """
  def update_todo_position(%Scope{} = scope, %Todo{} = todo, new_index) do
    Ecto.Multi.new()
    |> multi_reposition(:new, todo, {Renku, todo.renku_id}, new_index, renku_id: todo.renku_id)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        new_todo = %Todo{todo | position: new_index}

        log =
          ActivityLog.log(scope, todo, %{
            action: "todo_position_updated",
            subject_text: todo.title,
            before_text: todo.position,
            after_text: new_index
          })

        broadcast(scope, %Events.TodoRepositioned{todo: new_todo, log: log})

        :ok

      {:error, _failed_op, failed_val, _changes_so_far} ->
        {:error, failed_val}
    end
  end

  def change_todo(todo_or_changeset, attrs \\ %{}) do
    Todo.changeset(todo_or_changeset, attrs)
  end

  @doc """
  Moves a todo from one renku to another.

  Broadcasts %Events.TodoDeleted{} on the scoped topic for the old renku.
  Broadcasts %Events.TodoRepositioned{} on the scoped topic for the new renku.
  """
  def move_todo_to_renku(%Scope{} = scope, %Todo{} = todo, %Renku{} = renku, at_index) do
    Ecto.Multi.new()
    |> Repo.multi_transaction_lock(:old_renku, {Renku, todo.renku_id})
    |> Repo.multi_transaction_lock(:new_renku, renku)
    |> multi_update_all(:dec_positions, fn _ ->
      from(t in Todo,
        where: t.renku_id == ^todo.renku_id,
        where:
          t.position > subquery(from og in Todo, where: og.id == ^todo.id, select: og.position),
        update: [inc: [position: -1]]
      )
    end)
    |> Ecto.Multi.run(:pos_at_end, fn repo, _changes ->
      position = repo.one(from t in Todo, where: t.renku_id == ^renku.id, select: count(t.id))
      {:ok, position}
    end)
    |> multi_update_all(:move_to_renku, fn %{pos_at_end: pos_at_end} ->
      from(t in Todo,
        where: t.id == ^todo.id,
        update: [set: [renku_id: ^renku.id, position: ^pos_at_end]]
      )
    end)
    |> multi_reposition(:new, todo, renku, at_index, renku_id: renku.id)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        new_todo = %Todo{todo | renku: renku, renku_id: renku.id, position: at_index}

        log =
          ActivityLog.log(scope, new_todo, %{
            action: "todo_moved",
            subject_text: new_todo.title,
            before_text: todo.renku.title,
            after_text: renku.title
          })

        broadcast(scope, %Events.TodoDeleted{todo: todo})
        broadcast(scope, %Events.TodoRepositioned{todo: new_todo, log: log})

        :ok

      {:error, _failed_op, failed_val, _changes_so_far} ->
        {:error, failed_val}
    end
  end

  @doc """
  Deletes a todo for the current scope.

  Broadcasts %Events.TodoDeleted{} on the scoped topic when successful.
  """
  def delete_todo(%Scope{} = scope, %Todo{} = todo) do
    Ecto.Multi.new()
    |> Repo.multi_transaction_lock(:renku, {Renku, todo.renku_id})
    |> multi_decrement_positions(:dec_rest_in_renku, todo, renku_id: todo.renku_id)
    |> Ecto.Multi.delete(:todo, todo)
    |> Repo.transaction()
    |> case do
      {:ok, %{todo: todo}} ->
        log =
          ActivityLog.log(scope, todo, %{
            action: "todo_deleted",
            subject_text: todo.title,
            after_text: todo.renku.title
          })

        broadcast(scope, %Events.TodoDeleted{todo: todo, log: log})

        {:ok, todo}

      {:error, _failed_op, failed_val, _changes_so_far} ->
        {:error, failed_val}
    end
  end

  @doc """
  List todos for the current scope.
  """
  def list_todos(%Scope{} = scope, limit) do
    Repo.all(
      from(t in Todo,
        where: t.user_id == ^scope.current_user.id,
        limit: ^limit,
        order_by: [asc: :position]
      )
    )
  end

  @doc """
  Toggles a todo status for the current scope.

  Broadcasts %Events.TodoToggled{} on the scoped topic when successful.
  """
  def toggle_complete(%Scope{} = scope, %Todo{} = todo) do
    new_status =
      case todo.status do
        :completed -> :started
        :started -> :completed
      end

    query = from(t in Todo, where: t.id == ^todo.id and t.user_id == ^scope.current_user.id)
    {1, _} = Repo.update_all(query, set: [status: new_status])
    new_todo = %Todo{todo | status: new_status}

    log =
      ActivityLog.log(scope, new_todo, %{
        action: "todo_toggled",
        subject_text: todo.title,
        before_text: todo.status,
        after_text: new_status
      })

    broadcast(scope, %Events.TodoToggled{todo: new_todo, log: log})

    {:ok, new_todo}
  end

  def get_todo!(%Scope{} = scope, id) do
    from(t in Todo, where: t.id == ^id and t.user_id == ^scope.current_user.id)
    |> Repo.one!()
    |> Repo.preload(:renku)
  end

  @doc """
  Updates a todo for the current scope.

  Broadcasts %Events.TodoUpdated{} on the scoped topic when successful.
  """
  def update_todo(%Scope{} = scope, %Todo{} = todo, params) do
    todo
    |> Todo.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, new_todo} ->
        log =
          if todo.title != new_todo.title do
            ActivityLog.log(scope, new_todo, %{
              action: "todo_updated",
              subject_text: todo.title,
              after_text: new_todo.title
            })
          end

        broadcast(scope, %Events.TodoUpdated{todo: new_todo, log: log})

        {:ok, new_todo}

      other ->
        other
    end
  end

  @doc """
  Creates a todo for the current scope.

  Broadcasts %Events.TodoAdded{} on the scoped topic when successful.
  """
  def create_todo(%Scope{} = scope, %Renku{} = renku, params) do
    todo = %Todo{
      user_id: scope.current_user.id,
      status: :started,
      renku_id: renku.id
    }

    Ecto.Multi.new()
    |> Repo.multi_transaction_lock(:renku, renku)
    |> Ecto.Multi.run(:position, fn repo, _changes ->
      position = repo.one(from t in Todo, where: t.renku_id == ^renku.id, select: count(t.id))

      {:ok, position}
    end)
    |> Ecto.Multi.insert(:todo, fn %{position: position} ->
      Todo.changeset(%Todo{todo | position: position}, params)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{todo: todo}} ->
        log =
          ActivityLog.log(scope, todo, %{
            action: "todo_created",
            subject_text: todo.title,
            after_text: renku.title
          })

        broadcast(scope, %Events.TodoAdded{todo: todo, log: log})

        {:ok, todo}

      {:error, :todo, changeset, _changes_so_far} ->
        {:error, changeset}
    end
  end

  @doc """
  Returns the active renkus for the current scope.
  """
  def active_renkus(%Scope{} = scope, limit) do
    from(l in Renku,
      where: l.user_id == ^scope.current_user.id,
      limit: ^limit,
      order_by: [asc: :position]
    )
    |> Repo.all()
    |> Repo.preload(
      todos:
        from(t in Todo,
          where: t.user_id == ^scope.current_user.id,
          limit: @max_todos,
          order_by: [asc: t.position]
        )
    )
  end

  @doc """
  Gets a single renku owned by the scoped user.

  Raises `Ecto.NoResultsError` if the Renku does not exist.
  """
  def get_renku!(%Scope{} = scope, id) do
    from(l in Renku, where: l.user_id == ^scope.current_user.id, where: l.id == ^id)
    |> Repo.one!()
    |> preload()
  end

  defp preload(resource), do: Repo.preload(resource, [:todos])

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
        renku = Repo.preload(renku, :todos)

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

  defp multi_update_all(multi, name, func, opts \\ []) do
    Ecto.Multi.update_all(multi, name, func, opts)
  end

  defp broadcast(%Scope{} = scope, event) do
    Phoenix.PubSub.broadcast(Linku.PubSub, topic(scope), {__MODULE__, event})
  end

  defp topic(%Scope{} = scope), do: "todos:#{scope.current_user.id}"

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

  def test(to, %Scope{} = scope) do
    parent = self()
    Node.spawn_link(to, fn ->
      IO.inspect(scope)
      send(parent, {:done, node()})
    end)
  end
end
