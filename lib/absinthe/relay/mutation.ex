defmodule Absinthe.Relay.Mutation do
  @moduledoc """
  Support for building mutations with single inputs and client mutation IDs.

  The `payload` macro can be used by schema designers to support mutation
  fields that receive a single input object argument with a client mutation ID
  and return that ID as part of the response payload.

  More information can be found at:
  - https://facebook.github.io/relay/docs/graphql-mutations.html
  - https://facebook.github.io/relay/graphql/mutations.htm

  ## Example

  In this example we add a mutation field `:simple_mutation` that
  accepts an `input` argument (which is defined for us automatically)
  which contains an `:input_data` field.

  We also declare the output will contain a field, `:result`.

  Notice the `resolve` function doesn't need to know anything about the
  wrapping `input` argument -- it only concerns itself with the contents
  -- and the client mutation ID doesn't need to be dealt with, either. It
  will be returned as part of the response payload automatically.

  ```
  mutation do
    payload field :simple_mutation do
      input do
        field :input_data, non_null(:integer)
      end
      output do
        field :result, :integer
      end
      resolve fn
        %{input_data: input_data}, _ ->
          # Some mutation side-effect here
          {:ok, %{result: input_data * 2}}
      end
    end
  end
  ```

  Here's a query document that would hit this field:

  ```graphql
  mutation DoSomethingSimple {
    simpleMutation(input: {inputData: 2, clientMutationId: "abc"}) {
      result
      clientMutationId
    }
  }
  ```

  And here's the response:

  ```json
  {
    "data": {
      "simpleMutation": {
        "result": 4,
        "clientMutationId": "abc"
      }
    }
  }
  ```

  Note the above code would create the following types in our schema, ad hoc:

  - `SimpleMutationInput`
  - `SimpleMutationPayload`

  For this reason, the identifier passed to `payload field` must be unique
  across your schema.

  ## Macros

  For more details on `payload` and other mutation-related macros, see
  `Absinthe.Relay.Mutation.Notation`.

  """

  @doc false
  # System resolver to extract values from the input and return the
  # client mutation ID as part of the response.
  def resolve_with_input(designer_resolver) do
    fn
      %{input: input}, info ->
        mut_id = case input do
          %{client_mutation_id: mut_id} -> mut_id
          _ -> random_string()
        end
        case Absinthe.Resolution.call(designer_resolver, input, info) do
          {flag, value} when is_map(value) ->
            {flag, Map.put(value, :client_mutation_id, mut_id)}
          other ->
            # On your own!
            other
        end
      _args, info ->
        Absinthe.Resolution.call(designer_resolver, %{}, info)
    end
  end
  def resolve_with_input(_, info, designer_resolver) do
    Absinthe.Resolution.call(designer_resolver, %{}, info)
  end

  def random_string(length \\ 32) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64 |> binary_part(0, length)
  end

end
