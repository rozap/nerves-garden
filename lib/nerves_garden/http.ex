defmodule NervesGarden.Http do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/" do
    state = NervesGarden.state |> inspect

    body =
      """
      <html>
        <head>
          <title>garden</title>
        </head>
        <body>
          #{state}
        </body>
      </html>
      """

    conn
    |> put_resp_header("Content-Type", "text/html")
    |> send_resp(200, body)
  end
end
