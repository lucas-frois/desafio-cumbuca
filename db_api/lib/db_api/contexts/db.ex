defmodule DbApi.Db do

  def run_command(command, client_name) do
    with {:ok, [db_path, transactions_list_path, transactions_data_path]} <- ensure_database_files_created(),
         {:ok, [validated_command, key, value]} <- validate_command(command) do

      file_paths = [db_path, transactions_list_path, transactions_data_path]

      case validated_command do
        "get" -> fetch_record(key, client_name, file_paths)
        "set" -> create_or_update_record(key, value, client_name, file_paths)
        "begin" -> start_transaction(client_name, file_paths)
        "commit" -> commit_transaction(client_name, file_paths)
        "rollback" -> revert_transaction(client_name, file_paths)
        _ -> {:error, "Invalid command."}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_record(key, client_name, [db_path, transactions_list_path, transactions_data_path]) do
    file_to_read = if has_open_transaction?(transactions_list_path, client_name),
                    do: transactions_data_path,
                    else: db_path

    lines = read_file(file_to_read)

    case find_record_by_key(lines, key) do
      nil ->
        {:error, "Record not found"}

      record ->
        {:ok, extract_value_from_record(record)}
    end
  end

  defp find_record_by_key(lines, key) do
    Enum.find(lines, fn line ->
      String.starts_with?(line, "#{key};")
    end)
  end

  defp extract_value_from_record(record) do
    record
    |> String.split(";")
    |> List.last()
  end

  defp create_or_update_record(key, value, client_name, [db_path, transactions_list_path, transactions_data_path]) do
    target_file_path = if has_open_transaction?(transactions_list_path, client_name),
                       do: transactions_data_path,
                       else: db_path

    lines = read_file(target_file_path)

    case find_record_by_key(lines, key) do
      nil ->
        new_lines = ["#{key};#{value}" | lines]
        write_file(target_file_path, new_lines)
        {:ok, "#{nil} #{value}"}

      existing_record ->
        previous_value = extract_value_from_record(existing_record)

        updated_lines = Enum.map(lines, fn line ->
          if String.starts_with?(line, "#{key};"), do: "#{key};#{value}", else: line
        end)

        write_file(target_file_path, updated_lines)
        {:ok, "#{previous_value} #{value}"}
    end
  end

  defp read_file(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.reject(&String.trim/1 == "")
  end

  defp write_file(path, content) do
    content
    |> Enum.join("\n")
    |> then(&File.write(path, &1, [:write]))
  end

  defp has_open_transaction?(path, client_name) do
    path
    |> read_file()
    |> Enum.any?(fn line -> line == client_name end)
  end

  defp create_transaction(file_path, client_name) do
    file_path
    |> read_file()
    |> then(fn lines -> [client_name | lines] end)
    |> then(&write_file(file_path, &1))
  end

  defp start_transaction(client_name, [_db_path, transactions_list_path, _transactions_data_path]) do
    if has_open_transaction?(transactions_list_path, client_name) do
      {:error, "Transaction already in progress"}
    else
      create_transaction(transactions_list_path, client_name)
      {:ok, "Transaction started"}
    end
  end


  # commit
  # verifica se existe uma transacao
  # se nao, retorna erro (nao tem isso na descricao do desafio mas faz sentido)
  # se sim, verifica se a transacao é aplicavel, isto é,
  # o valor das chaves modificadas dentro da transacao
  # nao pode ter sido alterado fora da transacao

  defp commit_transaction(client_name, paths) do
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
  defp revert_transaction(client_name, [db_path, transactions_list_path, transactions_data_path]) do

    if has_open_transaction(transactions_list_path, client_name) do
      {:error, "ERR - cannot rollback with transaction level equals to zero"}
    else
      transaction_db_records = read_file(transactions_data_path)

      updated_lines = Enum.filter(transaction_db_records, fn record ->
        String.split(record, ";") |> List.first() != client_name
      end)

      write_file(transactions_data_path, updated_lines)

      transactions_list = read_file(transactions_list_path)

      updated_transactions_list = transactions_list
      |> Enum.filter(fn client -> client != client_name end)

      write_file(transactions_list_path, updated_transactions_list)

      {:ok, "OK"}
    end
  end

  defp ensure_database_files_created do
    storage_path = Path.join([System.user_home!(), "CumbucaDb", "storage"])

    files = [
      db_filename: "db.txt",
      transactions_list_filename: "transactions-list.txt",
      transactions_data_filename: "transactions-data.txt"
    ]

    File.mkdir_p!(storage_path)

    paths = Enum.map(files, fn {_name, filename} ->
      full_path = Path.join(storage_path, filename)
      ensure_file_created(full_path)
      full_path
    end)

    {:ok, paths}
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
