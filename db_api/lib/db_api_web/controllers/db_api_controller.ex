defmodule DbApiWeb.DbApiController do
  import Plug.Conn

  use DbApiWeb, :controller

  alias DbApi.Db

  def post(conn, params) do

    {:ok, body, _conn_details} = Plug.Conn.read_body(conn)

    case get_req_header(conn, "x-client-name") do
      [] ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(401, "ERR: not authorized - x-client-name header is required.")

        [client_name_header] ->
          command = body
          client_name = client_name_header

          with {:ok, result} <- Db.run_command(command, client_name) do
            conn
            |> put_resp_content_type("text/plain")
            |> put_status(:ok)
            |> send_resp(200, result)
          else
            {:error, reason} ->
              conn
              |> put_resp_content_type("text/plain")
              |> put_status(:bad_request)
              |> send_resp(400, reason)
          end
    end
  end
end
