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

# preparando o nome dos arquivos
todo="tarefas-todo.txt"
done="tarefas-done.txt"

# uma espécie de template para organizar todos os identificadores nas linhas
montar_tarefa() {
  # pegando o id da tarefa
  local id="$1"

  # adiciona tarefa com data limite (obrigatório seguir o formato AAAAMMDD)
  if [ -n "$deadline" ]; then
    # adiciona tarefa com data limite e prioridade (a prioridade padrão é 1)
    if [ -n "$prio" ]; then
      echo "$id: \"$tarefa\" ($deadline +$prio)"
    else
      echo "$id: \"$tarefa\" ($deadline)"
    fi
  # adiciona tarefa somente com prioridade e por fim adiciona apenas a tarefa
  elif [ -n "$prio" ]; then
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
  linha=$(montar_tarefa "$id")
  
  # finalmente adicionando a linha
  echo "$linha" >> "$todo"
  echo "Tarefa $linha adicionada."
}

#----------------------------------------------------------------------------------------

selecionar_deadline()
{
  grep -E "\([0-9]{8}\)" "$arquivo"
}

selecionar_prio()
{
  while IFS= read -r linha; do
    [[ $linha =~ \+[0-9]+ ]] && echo "$linha"
  done < "$arquivo" | sort -t'+' -k2,2nr
}

selecionar_simples() {
  tail -n +2 "$arquivo" | while read -r linha; do
    [[ $linha =~ \+[0-9]+ ]] && continue
    [[ $linha =~ \([0-9]{8}\)$ ]] && continue
    echo "$linha"
  done
}

list() {
  arquivo="$1"
  
  if [[ "$argumentos" == *"--deadline"* ]]; then
    selecionar_deadline
    selecionar_prio
    selecionar_simples
  elif [[ "$argumentos" == *"--prio"* ]]; then
    selecionar_prio
    selecionar_deadline
    selecionar_simples
  else
    tail -n +2 "$arquivo"
  fi
}

# ----------------------------------------------------------------
edit()
{
  # edita tarefa 1, adicionando prioridade
  echo "edit"
}
# -----------------------------------------------------------------

# remove as linhas, podendo ser usada em outras funções subsequêntes
remover_linha()
{
  # pela passagem do arquivo, apaga a linha desejada através do id
  arquivo="$1" && grep -q "^$id_busca" "$arquivo" || die "Esta tarefa não existe..."
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
  [ -n "$linha" ] || die "Esta tarefa não existe..."
  
  # "movendo" a linha da listas de fazer para a lista de realizadas
  echo "$linha" >> "$done"
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

uso()
{
  echo "USO..."
}

main()
{
  # Salvando o comando e os argumentos da string
  comando="$1"
  argumentos="$*"

  # Pulando o comando para trabalhar nos argumentos
	shift
	
  # Preparando o arquivo
	[ -f "$todo" ] || echo "TAREFAS:" > $todo
	
  # id de busca algumas opções 
  id_busca="$1"
  linha=$(sed -n "/^$id_busca/p; /^$id_busca/q" "$todo")
  
  # opções de comandos para o usuário selecionar
	case "$comando" in
		add)
      salvar_identificadores "$@"
			add
			;;
		list)
      #salvar_identificadores "$@" ########
			list "$todo"
			;;
		edit)
      salvar_identificadores "$@"
      edit
			;;
		delete)
		  delete
			;;
    do)
      do_tarefa
      ;;
    list-done)
      list "$done"
      ;;
      *)
			uso
	esac
	
}

# iniciando a main se o comando for coerente com o uso
[ "$1" ] && main "$@" || uso
