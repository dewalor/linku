defmodule Linku.Events do
  @moduledoc """
  Defines Event structs for use within the pubsub system.
  """
  defmodule RenkuAdded do
    defstruct renku: nil, log: nil
  end

  defmodule RenkuUpdated do
    defstruct renku: nil, log: nil
  end

  defmodule TodoAdded do
    defstruct todo: nil, log: nil
  end

  defmodule TodoUpdated do
    defstruct todo: nil, log: nil
  end

  defmodule TodoDeleted do
    defstruct todo: nil, log: nil
  end

  defmodule TodoRepositioned do
    defstruct todo: nil, log: nil
  end

  defmodule TodoMoved do
    defstruct todo: nil, from_renku_id: nil, to_renku_id: nil, log: nil
  end

  defmodule RenkuRepositioned do
    defstruct renku: nil, log: nil
  end

  defmodule TodoToggled do
    defstruct todo: nil, log: nil
  end

  defmodule RenkuDeleted do
    defstruct renku: nil, log: nil
  end
end
