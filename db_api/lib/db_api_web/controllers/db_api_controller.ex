defmodule DbApiWeb.DbApiController do
  use DbApiWeb, :controller
  import Plug.Conn

  alias DbApi.Db

  def post(conn, _params) do
    with {:ok, body, _conn_details} <- read_body(conn),
         [client_name] <- get_req_header(conn, "x-client-name"),
         {:ok, result} <- Db.run_command(body, client_name) do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(:ok, result)
    else
      [] ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(401, "ERR: not authorized - x-client-name header is required.")

      {:error, reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(:bad_request, reason)
    end
  end
end
