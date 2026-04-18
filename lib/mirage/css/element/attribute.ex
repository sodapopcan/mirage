# Adapted from the Meeseeks library (https://hex.pm/packages/meeseeks).

defmodule Mirage.CSS.Element.Attribute.Attribute do
  @moduledoc false
  defstruct attribute: nil
end

defmodule Mirage.CSS.Element.Attribute.AttributePrefix do
  @moduledoc false
  defstruct attribute: nil
end

defmodule Mirage.CSS.Element.Attribute.Value do
  @moduledoc false
  defstruct attribute: nil, value: nil
end

defmodule Mirage.CSS.Element.Attribute.ValueContains do
  @moduledoc false
  defstruct attribute: nil, value: nil
end

defmodule Mirage.CSS.Element.Attribute.ValueDash do
  @moduledoc false
  defstruct attribute: nil, value: nil
end

defmodule Mirage.CSS.Element.Attribute.ValueIncludes do
  @moduledoc false
  defstruct attribute: nil, value: nil
end

defmodule Mirage.CSS.Element.Attribute.ValuePrefix do
  @moduledoc false
  defstruct attribute: nil, value: nil
end

defmodule Mirage.CSS.Element.Attribute.ValueSuffix do
  @moduledoc false
  defstruct attribute: nil, value: nil
end
