defmodule DbApi.Db do

  def run_command(command, client_name) do

    case ensure_files_created() do
      {:error} -> {:error, "ERR - file permissions"}
      {:ok, [db_fullpath, transactions_list_fullpath, transactions_data_fullpath]} ->
        case validate_commands(command) do
          {:error, reason} -> {:error, reason}
          {:ok, [command, key, value]} ->
            paths = [db_fullpath, transactions_list_fullpath, transactions_data_fullpath]

            case command do
              "get" -> handleGet(key, client_name, paths)
              "set" -> handleSet(key, value, client_name, paths)
              "begin" -> handle_begin(client_name, paths)
              "commit" -> handleCommit(client_name, paths)
              "rollback" -> handleRollback(client_name, paths)
              _ -> {:error, "No command match."} # will never happen
            end
        end
    end
  end

  # banco
  # será armazenado os registros na forma de key;value
  # se alguma key ou value tiver ;, vai quebrar
  # eh o melhor que consigo fazer agora

  # get
  # verifica se tem transacao aberta pro client_name
  # se sim, le do banco temporário
  # se nao, le do banco real
  defp handleGet(key, client_name, paths) do
    [db_fullpath, transactions_list_fullpath, transactions_data_fullpath] = paths

    has_open_transaction = has_open_transaction(transactions_list_fullpath, client_name)

    lines = cond do
      has_open_transaction -> read_file(transactions_data_fullpath)
      true -> read_file(db_fullpath)
    end

    match_function = fn (x) -> String.starts_with?(x, "#{key};") end

    record = Enum.find(lines, nil, match_function)

    case record do
      nil -> {:error, nil}
      _ ->
        [_, value] = String.split(record, ";") |> List.last()
        {:ok, value}
    end
  end

  # set (upsert)
  # verifica se tem transacao aberta pro client_name;
  # se sim, escreve no banco temporario; se nao, escreve no banco real
  # - upsert => cria ou atualiza; se atualiza, retorna valor antigo; se cria, retorna nil
  defp handleSet(key, value, client_name, paths) do
    [db_fullpath, transactions_list_fullpath, transactions_data_fullpath] = paths

    has_open_transaction = has_open_transaction(transactions_list_fullpath, client_name)

    desired_db_path = cond do
      has_open_transaction = transactions_data_fullpath
      true = db_fullpath
    end

    lines = read_file(desired_db_path)

    match_function = fn (x) -> String.starts_with?(x, "#{key};") end

    record = Enum.find(lines, nil, match_function)

    doesRecordExists = record === nil

    case doesRecordExists do
      false ->
        content = ["#{key};#{value}" | lines]
        write_file(desired_db_path, content)
        {:ok, "#{nil} #{value}"}
      true ->
        [_, previous_value] = String.split(record, ";") |> List.last()
        updated_lines = lines
          |> Enum.map(fn item ->
            [xkey, xvalue] = String.split(item, ";")
            if xkey == key, do: "#{key};#{value}", else: item
          end)
          write_file(desired_db_path, updated_lines)
        {:ok, "#{previous_value} #{value}"}
    end
  end

  defp read_file(path) do
    lines = path
    |> File.read!()
    |> String.split("\n")

    lines
  end

  defp write_file(path, content) do
    lines = Enum.join(content, "\n") # content is a list

    File.write(path, lines, [:write])
  end

  defp has_open_transaction(file_path, client_name) do
    lines = read_file(file_path)

    Enum.member?(lines, client_name)
  end

  defp create_transaction(file_path, client_name) do
    lines = read_file(file_path)

    updatedLines = [client_name | lines]

    write_file(file_path, updatedLines)
  end

  # begin
  # verifica se já existe uma transacao
  # se sim, retorna erro;
  # se nao, cria um registro nos arquivo de listas de transacoes e retorna :ok
  defp handle_begin(client_name, paths) do
    [db_fullpath, transactions_list_fullpath, transactions_data_fullpath] = paths

    has_open_transaction = has_open_transaction(transactions_list_fullpath, client_name)

    case has_open_transaction do
      true -> {:error, "ERR - transaction has already been started."}
      false ->
        create_transaction(transactions_list_fullpath, client_name)
        {:ok, "OK"}
    end
  end


  # commit
  # verifica se existe uma transacao
  # se nao, retorna erro (nao tem isso na descricao do desafio mas faz sentido)
  # se sim, verifica se a transacao é aplicavel, isto é,
  # o valor das chaves modificadas dentro da transacao
  # nao pode ter sido alterado fora da transacao

  defp handleCommit(client_name, paths) do
    [db_fullpath, transactions_list_fullpath, transactions_data_fullpath] = paths

    has_open_transaction = has_open_transaction(transactions_list_fullpath, client_name)

    case has_open_transaction do
      false -> {:error, "ERR - cannot commit without open transaction"}
      true ->
        transaction_db_lines = read_file(transactions_data_fullpath)
        |> Enum.filter(fn record ->
          String.split(record, ";") |> List.first() == client_name
        end)

        transaction_db_records =
          transaction_db_lines
        |> Enum.map(fn record ->
          record |> String.split(";") |> tl()
        end)

        transaction_db_keys =
          transaction_db_records
          |> Enum.filter(fn record ->
            String.split(";") |> List.first()
          end)

        real_db = read_file(db_fullpath)

        real_db_records_with_matching_keys =
          real_db
          |> Enum.filter(fn record ->
            key = record |> String.split() |> List.first()

            Enum.member?(transaction_db_keys, key)
          end)




    end
  end

  # rollback
  # verifica se existe uma transacao acontecendo; se nao, retorna erro
  # se sim, apaga os registros correspondentes nos dois arquivos de transacao
  defp handleRollback(client_name, paths) do
    [db_fullpath, transactions_list_fullpath, transactions_data_fullpath] = paths

    has_open_transaction = has_open_transaction(transactions_list_fullpath, client_name)

    case has_open_transaction do
      true -> {:error, "ERR - cannot rollback with transaction level equals to zero"}
      false ->
        transcation_db_records = read_file(transactions_data_fullpath)

        updated_lines = transcation_db_records
          |> Enum.filter(fn record ->
            String.split(record, ";") |> List.first() != client_name
          end)
          write_file(transactions_data_fullpath, updated_lines)

          updated_transactions_list = read_file(transactions_list_fullpath)
            |> Enum.filter(fn client ->
              client != client_names
            end)

          write_file(transactions_list_fullpath, updated_transactions_list)
        {:ok, "OK"}
    end
  end

  defp ensure_files_created() do
    db_filename = "db.txt"
    transactions_list_filename = "transactions-list.txt"
    transactions_data_filename = "transactions-data.txt"
    storage_path = Path.join([System.user_home!(), "CumbucaDb", "storage"])

    db_fullpath = Path.join(storage_path, db_filename)
    transactions_list_fullpath = Path.join(storage_path, transactions_list_filename)
    transactions_data_fullpath = Path.join(storage_path, transactions_data_filename)

    :ok = File.mkdir_p!(storage_path)

    ensure_file_created(db_fullpath)
    ensure_file_created(transactions_list_fullpath)
    ensure_file_created(transactions_data_fullpath)

    {:ok, [db_fullpath, transactions_list_fullpath, transactions_data_fullpath]}
  end

  defp ensure_file_created(file_path) do
    unless File.exists?(file_path) do
      File.write!(file_path, "")
    end
  end

  defp validate_commands(command) when is_binary(command) do
    allowed_commands = ["set", "get", "begin", "rollback", "commit"]
    keywords = String.split(command, " ", trim: true)

    case keywords do
      [cmd, key, value] ->
        command_lowercase = String.downcase(cmd)

        if Enum.member?(allowed_commands, command_lowercase) do
          {:ok, [cmd, key, value]}
        else
          {:error, "ERR:'No command #{cmd}'"}
        end

        _ ->
          #{:error, "ERR: '#{command}' - Syntax error"} - fix validation over commands
          {:ok, [cmd, key, value]}
    end
  end
end
