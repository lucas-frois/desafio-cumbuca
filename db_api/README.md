# DbApi - desafio cumbuca backend senior

# Como rodar
- Tenha Erlang e Elixir instalado na sua máquina
- no diretório principal da aplicaçao, rode mix phx.server

# Como testar
- Envie requesiçoes POST para localhost:4000/api/db
- Deve conter o header Content-Type: text/plain
- O body deve conter o comando desejado

# Decisoes arquiteturais
Decidi implementar a ideia do banco e transactions com tres arquivos:
1) db.txt - banco 'real', sem transacoes aplicadas. registros estao salvos no formato de "<key>;<value>"
2) transactions-list.txt - arquivo com client_names que possuem uma transacao em aberto
3) transactions-data.txt - arquivo com as operacoes que estao em estado transacional. registros estao no formato de "<client_name>;<key>;<value>"

# Comentários ao revisor

Olá! 
1) Eu sei que esse código está horrível kkk
2) Apesar de ter sido me dado um tempo gigante pra fazer esse desafio, as últimas semanas foram bem conturbadas (sobrecarga no trabalho + layoff + duas internaçoes + problemas pessoais. what a week, huh?). Apesar disso, o código nao foi feito com má vontade ou preguiça; eu me esforcei bastante :) Fiz o que pude com uns 3 dias que consegui focar nele.
3) Eu nao tinha nenhum conhecimento prévio em Elixir ou Phoenix. Sei um pouco de F#, mas o básico. Sei que a aplicaçao nao está seguindo _boas práticas_ de FP.
4) Testes de integraçao nao foram feitos.
5) O código (muito provavelmente) nao está funcional. Novamente, fiz o que consegui no tempo que tive.
