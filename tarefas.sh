#!/bin/bash

# This program is free software: you can redistribute it and/or modify 
# it under the terms of the GNU General Public License as published by 
# the Free Software Foundation, either version 3 of the License, or (at 
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but 
# WITHOUT ANY WARRANTY; without even the implied warranty of 
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
# General Public License for more details. 
#
# You should have received a copy of the GNU General Public License 
# along with this program. If not, see <https://www.gnu.org/licenses/>.

# preparando a variável de ambiente para definir um diretório padrão
TAREFAS_DIR="${TAREFAS_DIR:-.}"

# definindo o nome e caminho para os arquivos
todo="$TAREFAS_DIR/tarefas-todo.txt"
done="$TAREFAS_DIR/tarefas-done.txt"

# uma espécie de template para organizar todos os identificadores nas linhas
montar_tarefa() {
  # pegando o id da tarefa
  local id="$1"

  # adiciona tarefa com data limite (obrigatório seguir o formato AAAAMMDD)
  if [ -n "$deadline" ]; then
    [[ $deadline =~ ^[0-9]{8}$ ]] || die "use o formato AAAAMMDD (ex: 20260608)."

    # adiciona tarefa com data limite e prioridade (a prioridade padrão é 1)
    if [ -n "$prio" ]; then
      [[ $prio =~ ^[1-9][0-9]*$ ]] || die "defina a prioridade a partir de 1 (padrão)."

      echo "$id: \"$tarefa\" ($deadline +$prio)"
    else
      echo "$id: \"$tarefa\" ($deadline)"
    fi
  # adiciona tarefa somente com prioridade e por fim, adiciona somente a tarefa
  elif [ -n "$prio" ]; then
    [[ $prio =~ ^[1-9][0-9]*$ ]] || die "defina a prioridade a partir de 1 (padrão)."
    echo "$id: \"$tarefa\" (+$prio)"
  else
    echo "$id: \"$tarefa\""
  fi
}

# adiciona uma nova tarefa
add()
{
  # tratando o erros no nome da tarefa não ser sido passsada
	[ ! -z "$tarefa" ] || 
		die "não existe um nome para a nova tarefa"
  
  # e caso o arquivo de tarefas a fazer não exista criando-o
  [ -s "$todo" ] || echo "TAREFAS:" > "$todo"
  
  # preparando a string da linha para adicioná-la através do id
  id=$(wc -l < "$todo")
  linha=$(montar_tarefa "$id") || { echo "$linha"; exit 1; }
  
  # finalmente adicionando a linha
  echo "$linha" >> "$todo"
  echo "Tarefa $linha adicionada."
}

# seleciona apenas as linhas com deadline
selecionar_deadline()
{
  # mostra as linhas ordenadas com o padrão de 8 números
  grep -E "\([0-9]{8}\)" "$arquivo" | sort -t'(' -k2,2n
}

# seleciona e ordena as linhas de acordo com a prioridade
selecionar_prio()
{
  # busca o padrão e formata a saída ordenada
  while IFS= read -r linha; do
    [[ $linha =~ \([0-9]{8}\) ]] && continue  # evitar duplas
    [[ $linha =~ \+[0-9]+ ]] && echo "$linha"
  done < "$arquivo" | sort -t'+' -k2,2nr
}

# seleciona somente linhas sem deadline e sem prioridade
selecionar_simples() {
  tail -n +2 "$arquivo" | while read -r linha; do
    [[ $linha =~ \+[0-9]+ ]] && continue
    [[ $linha =~ \([0-9]{8}\)$ ]] && continue
    echo "$linha"
  done
}

# mostrar todas as tarefas
list() {
  arquivo="$1"
  
  # mostrar todas as tarefas ordenando por data
  if [[ "$argumentos" == *"--deadline"* ]]; then
    selecionar_deadline
    selecionar_prio
    selecionar_simples

  # mostrar todas as tarefas ordenando por prioridade
  elif [[ "$argumentos" == *"--prio"* ]]; then
    selecionar_prio
    selecionar_deadline
    selecionar_simples
  else
    
    # tarefas por padrão, ordena por identificador
    tail -n +2 "$arquivo"
  fi
}

# edita tarefas, adicionando prioridade
edit()
{
  # trata do caso de a tarefa não existir na lista
  grep -q "^$id_busca:" "$todo" || die "esta tarefa não existe..."
  
  # pega exatamente o nome da tarefa para colocá-lo na linha
  tarefa=$(grep "^$id_busca:" "$todo" | sed -E 's/^[^"]*"([^"]*)".*$/\1/')
  

  # formata a linha e organiza os identificadores, erros são tratados
  nova_linha=$(montar_tarefa "$id_busca") || { echo "$nova_linha"; exit 1; }
  sed -i "s/^$id_busca:.*/$nova_linha/" "$todo" 
  echo "Tarefa $nova_linha atualizada."
}

# remove as linhas, podendo ser usada em outras funções subsequêntes
remover_linha()
{
  # pela passagem do arquivo, apaga a linha desejada através do id
  arquivo="$1" && grep -q "^$id_busca" "$arquivo" || die "esta tarefa não existe..."
  sed -i "0,/^$id_busca/{/^$id_busca/d}" "$arquivo"
}

# simplesmente deleta as tarefas
delete()
{
  remover_linha "$todo"
  echo "Tarefa $linha removida."
}

# completa as tarefas
do_tarefa()
{
  # e caso o arquivo de tarefas realizadas não exista criando-o
  [ -f "$done" ] || echo "TAREFAS:" > "$done"
  
  # seleciona a linha da tarefa buscada
  local linha
  linha=$(grep "^$id_busca:" "$todo")
  
  # tratando o erros para a inexistência da tarefa buscada
  [ -n "$linha" ] || die "esta tarefa não existe..."
  
  # "movendo" tarefa para a lista de realizadas com data e hora
  echo "$linha realizada em $(date +"%Y%m%d %H%M")." >> "$done"
  remover_linha "$todo"
  echo "Tarefa $linha realizada."
}

# esta função serve para tratar da estética das strings de erros
die()
{
	echo "tarefas.sh: $1"
	exit 1
}

# para indicar se há deadline ou prioridade
salvar_identificadores()
{
  while [ "$#" -gt 0 ]; do
		case "$1" in
			--deadline)
				deadline="$2"
				shift 2
				;;
			--prio)
				prio="$2"
				shift 2
				;;
			*)
				tarefa="$1"
				shift
				;;
		esac
	done
}

# encontra id referente a tarefa buscada na string
buscar_id()
{
  id_busca="$1"
  linha=$(sed -n "/^$id_busca/p; /^$id_busca/q" "$todo")
}

# exibe mensagem de uso como um mini manual
uso()
{
  echo " Uso: tarefas.sh comando tarefa (--deadline <date> --prio <number>)"
  echo "      tarefas.sh list (--deadline | --prio)"
  echo "      tarefas list-done (--deadline | --prio)"
  echo " "
  echo "      Tente 'tarefas.sh -h' ou 'tarefas.sh --help' para ajuda"
}

ajuda()
{
  echo " Uso: tarefas.sh comando tarefa (--deadline <date> --prio <number>)"
  echo "      tarefas.sh list (--deadline | --prio)"
  echo "      tarefas list-done (--deadline | --prio)"
  echo " "
  echo " tarefas.sh é um script Bash para gerenciar uma lista de tarefas."
  echo " "
  echo " Comandos:"
  echo "  add,      adiciona uma nova tarefa comum ou com deadline e/ou prioridade"
  echo "  list,     lista ordenandamente todas as tarefas em deadline ou prioridade"
  echo "  edit,     edita uma tarefa existente alterando deadline e/ou prioridade"
  echo "  delete,   deleta uma tarefa existente a partir de seu identificador único"
  echo "  do,       realiza uma tarefa, movendo para a lista as tarefas concluídas"
  echo "  list-done lista todas as tarefas realizadas com data e hora da conclusão"
  echo " "
  echo " Ao usar 'tarefas.sh -h' ou 'tarefas.sh --help' estas informaçõe são exibidas."
  echo " "
  echo " Por padrão, tarefas.sh armazena seus arquivos de tarefas no diretório HOME."
  echo " No entanto, isso pode ser alterado definindo a variável de ambiente TAREFAS_DIR:"
  echo "    export TAREFAS_DIR=/caminho/para/o/seu/diretório/escolhido"
}

# função principal
main()
{
  # Salvando o comando e os argumentos da string
  comando="$1"
  argumentos="$*"

  # Pulando o comando para trabalhar nos argumentos
	shift
	
  # Preparando o arquivo caso ele não exista
	[ -f "$todo" ] || echo "TAREFAS:" > "$todo"
	
  # opções de comandos para o usuário selecionar
	case "$comando" in
		add)
      salvar_identificadores "$@"
			add
			;;
		list)
			list "$todo"
			;;
		edit)
      buscar_id "$1"
      shift
      salvar_identificadores "$@"
      edit
			;;
		delete)
      buscar_id "$1"
		  delete
			;;
    do)
      buscar_id "$1"
      do_tarefa
      ;;
    list-done)
      list "$done"
      ;;
    -h|--help)
      ajuda
      ;;
    *)
			uso
      ;;
	esac
}

# iniciando a main ou exibe mensagem de uso
[ "$1" ] && main "$@" || uso
