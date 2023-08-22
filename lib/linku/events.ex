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

  defmodule RenkuPublished do
    defstruct renku: nil, log: nil
  end

  defmodule LineAdded do
    defstruct line: nil, log: nil
  end

  defmodule LineUpdated do
    defstruct line: nil, log: nil
  end

  defmodule LineDeleted do
    defstruct line: nil, log: nil
  end

  defmodule LineRepositioned do
    defstruct line: nil, log: nil
  end

  defmodule LineMoved do
    defstruct line: nil, from_renku_id: nil, to_renku_id: nil, log: nil
  end

  defmodule RenkuRepositioned do
    defstruct renku: nil, log: nil
  end

  defmodule LineToggled do
    defstruct line: nil, log: nil
  end

  defmodule RenkuDeleted do
    defstruct renku: nil, log: nil
  end
end
