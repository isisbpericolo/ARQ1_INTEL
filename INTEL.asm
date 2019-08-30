assume cs:codigo,ds:dados,es:dados,ss:pilha

CR  		EQU    	0DH ; constante - codigo ASCII do caractere "carriage return"
LF  		EQU    	0AH ; constante - codigo ASCII do caractere "line feed"
TAB 		EQU	   	9
SPACE 		EQU 	20H
BACKSPACE	EQU		8
ESCAPE 		EQU		1BH

;; DEFINIÇÃO DO SEGMENTO DE DADOS DO PROGRAMA
dados    	segment

msgHeaderUm		db 'Arquivo: '
nomeArquivo		db	13 dup (0) ;8 mais extensão
msgHeaderDois	db ' contem       caracteres com     espacos e TABS eliminados.', '$'

msgInicio		db 'Digite o nome do arquivo: ', '$'
msgErroUm		db 'Funcao invalida!', '$'
msgErroDois		db 'Arquivo nao encontrado!', '$'
msgErroTres		db 'Caminho nao encontrado!', '$'
msgErroQuatro	db 'Não existem mais handlers disponiveis!', '$'
msgErroCinco	db 'Acesso negado!', '$'
msgErroSeis		db 'Modo de acesso invalido!', '$'
msgErroExtensao	db 'Nome de arquivo incompativel com o programa!', CR, LF, 'O nome devera ter no maximo oito letras, excluindo uma extensao de 4 caracteres!', '$'
msgEncerramento	db 'Escolhestes encerrar o programa!', CR, LF, 'Espero que tenhas te divertido e que este trabalho lhe tenha sido util!', CR, LF, 'Boas ferias!', '$'
msgESC			db 'Pressione ESC para voltar a primeira etapa!', '$'

handlerFile 	dw ?
arquivo 		db 2000 dup (0)
bufferFile 		db 0

tamNomeArquivo	db 0
contadorLer		dw 0
contadorExcluir	dw 0
stringLer		db 5 dup (0)
stringExcluir	db 4 dup (0)
flagEspaco 		db 0
contadorLinha 	dw 0
guardaEspaco 	dw 0
;arquivoteste 	db 'tchau.txt', 0

dados   ends

;; DEFINIÇÃO DO SEGMENTO DE PILHA DO PROGRMA
pilha   segment stack ; permite inicializacao automatica de SS:SP
        dw     128 dup(?)
pilha   ends
         
;; DEFINIÇÃO DO SEGMENTO DE CÓDIGO DO PROGRAMA
codigo  segment

inicio:  ; CS e IP sao inicializados com este endereco
    mov    ax,dados ; inicializa DS
    mov    ds,ax    ; com endereco do segmento DADOS
    mov    es,ax    ; idem em ES
; fim da carga inicial dos registradores de segmento
;-------------------------------------------------------------------------------------------------------
etapaUm:
	;este trecho de código limpa a tela
	;ele será usado muitas vezes durante o programa, assinalado de forma mais simples como "limpa a tela"
	;primeiro, se inicializa os registradores com os valores necessários
	mov ch, 0 	;linha superior
	mov cl, 0 	;coluna esquerda
	mov dh, 24 	;linha inferior
	mov dl, 79	;coluna direita
	mov bh, 07h	;atributo de preenchimento
	mov al, 0	;número de linhas
	;chamada da função
	mov ah, 6
	int 10h
	
	;este trecho de código move o cursor para uma posição específica
	;ele também será utilizado muitas vezes no código, assinalado de forma mais simples como "mover cursor"
	mov dh, 0	;linha
	mov dl, 0	;coluna
	mov bh, 0 	;página
	;chamada da função
	mov ah, 2
	int 10h

	;imprime na tela uma mensagem pedindo para o usuário digitar um nome de arquivo
    lea dx, msgInicio 	;endereço da string terminada por cifrão ($)  
	;chamada da função
    mov ah, 9               
    int 21h                	
	
	;inicializa a variável que guardará o número de caracteres digitados pelo usuário para ser o nome do arquivo
	mov tamNomeArquivo, 0
	;e coloca um ponteiro para uma string que guardará o nome do arquivo
	lea bx, nomeArquivo
salvaNomeArquivo:
	;chamada da função que esperará um caractere ser digitado e retornará ele num registrador
	mov ah, 0
	int 16h
	;compara o caractere digitado com um carriage return
	cmp al, CR
	;se é um CR, significa que a pessoa terminou de digitar o que queria
	;e daí partimos para checar se a extensão existe e está correta antes de finalizar a string com o nome do arquivo
	je checaExtensao
	;compara o caractere digitado com um backspace
	cmp al, BACKSPACE
	je trataBackspace
	;salva caractere na string e ecoa na tela
	mov [bx], al
	mov dl, al
	;chamada da função
	mov ah, 2
	int 21h
	;incrementa posição na string
	inc bx 
	;e também o tamanho do nome do arquivo
	inc tamNomeArquivo
	jz checaExtensao
	jmp salvaNomeArquivo
checaExtensao:
	;se foi pressionado enter de primeira, encerra o programa
	cmp tamNomeArquivo, 0
	je encerraPrograma
	;subtrai quatro unidades no índice de posição da string de nome do arquivo (quatro pois '.txt' são quatro caracteres)
	sub bx, 4
	;testa se a extensão existe e está correta
	cmp [bx], 742eh ;'.t'
	;se não, a aplica
	jne aplicarExtensao
	;se sim, retorna o índice de posição ao seu estado anterior
	add bx, 4
finalizaNomeArquivo:
	;finaliza a string
	mov [bx], '$' 
	;e pula para abrir o arquivo
	jmp abrirArquivo

	trataBackspace:
	;se foi pressionado backspace sem nenhum caractere ter sido digitado antes,
	cmp tamNomeArquivo, 0
	;só volta ao laço de digitação
	je salvaNomeArquivo
	;se não, "imprime" um caractere de backspace para voltar uma posição na string
	mov dl, BACKSPACE
	mov ah, 2
	int 21h
	;depois imprime um espaço em cima do caractere que ali estava, para ser mais compreensivo ao usuário o que está acontecendo
	mov dl, ' '
	mov ah, 2
	int 21h
	;então volta-se outra posição na string, de novo imprimindo um backspace
	mov dl, BACKSPACE
	mov ah, 2
	int 21h
	;neste ponto, comparamos o contador de tamanho do nome do arquivo com 13, que é o número máximo que poderíamos ter
	cmp tamNomeArquivo, 13
	;se o nosso contador for maior que isso por ter sido incrementado antes, pulamos para onde iremos decrementá-lo
	jg decrementaContadorNomeArquivo
	;se não, só decrementamos a posição da string de nome do arquivo
	dec bx
	decrementaContadorNomeArquivo:
	dec tamNomeArquivo
	jmp salvaNomeArquivo
	
encerraPrograma:
	jmp fim
	
	aplicarExtensao:
	;se o nome do arquivo sem a extensão tem mais de oito caracteres (que é o limite),
	cmp tamNomeArquivo, 8
	;exibe mensagem de erro
	jg erroExtensao
	;se não, adiciona ao final da string '.txt'
	add bx, 4
	mov [bx], '.'
	inc bx
	mov [bx], 't'
	inc bx
	mov [bx], 'x'
	inc bx
	mov [bx], 't'
	inc bx
	;essa adição não é visível ao usuário
	jmp finalizaNomeArquivo
	
	erroExtensao:
	;limpa a tela
	mov ch, 0
	mov cl, 0
	mov dh, 24
	mov dl, 79
	mov bh, 07h
	mov al, 0
	mov ah, 6
	int 10h
	;move o cursor
	mov dh, 0
	mov dl, 0
	mov bh, 0
	mov ah, 2
	int 10h
	;exibe mensagem de erro
	lea dx, msgErroExtensao
	mov ah, 9
	int 21h
	;limpa o buffer do teclado e espera um caractere ser digitado pelo usuário
	mov al, 1
	mov ah, 0ch
	int 21h
	jz reiniciaPrograma
	reiniciaPrograma:
	jmp etapaUm
	
	
abrirArquivo:
	;abre arquivo usando função
	lea dx, nomeArquivo	;endereço de string com o nome do arquivo
	mov al, 0			;modo de leitura
	mov ah, 3dh
	int 21h
	;testa erro na abertura do arquivo
	jc errorAbertura
	;se não houver erro, salva o handler dado pela função
	jmp salvaHandler
	
	errorAbertura:
	;começa a testar os códigos de erro possíveis
	cmp ax, 1
	je firstError
	cmp ax, 2
	je secondError
	cmp ax, 3
	je thirdError
	cmp ax, 4
	je fourthError
	cmp ax, 5
	je fifthError
	cmp ax, 6
	je sixthError
	
	firstError:
	;move o cursor
	mov dh, 1
	mov dl, 0
	mov bh, 0
	mov ah, 2
	int 10h
	;exibe mensagem de erro
	lea dx, msgErroUm
	mov ah, 9
	int 21h
	jmp esperaDigitacao
	secondError:
	;move o cursor
	mov dh, 1
	mov dl, 0
	mov bh, 0
	mov ah, 2
	int 10h
	;exibe mensagem de erro
	lea dx, msgErroDois
	mov ah, 9
	int 21h
	jmp esperaDigitacao
	thirdError:
	;move o cursor
	mov dh, 1
	mov dl, 0
	mov bh, 0 
	mov ah, 2
	int 10h
	;exibe mensagem de erro
	lea dx, msgErroTres
	mov ah, 9
	int 21h
	jmp esperaDigitacao
	fourthError:
	;move o cursor
	mov dh, 1
	mov dl, 0
	mov bh, 0 
	mov ah, 2
	int 10h
	;exibe mensagem de erro
	lea dx, msgErroQuatro
	mov ah, 9
	int 21h
	jmp esperaDigitacao
	fifthError:
	;move o cursor
	mov dh, 1
	mov dl, 0
	mov bh, 0 
	mov ah, 2
	int 10h
	;exibe mensagem de erro
	lea dx, msgErroCinco
	mov ah, 9
	int 21h
	jmp esperaDigitacao
	sixthError:
	;move o cursor
	mov dh, 1
	mov dl, 0
	mov bh, 0 
	mov ah, 2
	int 10h
	;exibe mensagem de erro
	lea dx, msgErroSeis
	mov ah, 9
	int 21h
	jmp esperaDigitacao
	
	esperaDigitacao:
	;limpa o buffer do teclado e espera o usuário digitar algo
	mov al, 1
	mov ah, 0ch
	int 21h
	jz  voltaAoInicio
	jmp esperaDigitacao
	voltaAoInicio:
	;volta para o início do programa e exibe a mensagem de espera da digitação de um novo arquivo novamente
	jmp etapaUm
	
	salvaHandler:
	;guarda o número handler do arquivo em uma variável
	mov handlerFile, ax

	;inicializa o endereço de uma string que guardará o conteúdo do arquivo
	lea di, arquivo
	;e os contadores de número de caracteres lidos e excluídos
	mov contadorLer, 0
	mov contadorExcluir, 0
	
	proxCaractere:
	;começa um laço para ler os caracteres do arquivo um por um
	lea dx, bufferFile	;endereço de um buffer para o conteúdo do arquivo
	mov bx, handlerFile	;handler do arquivo
	mov cx, 1			;número de caracteres lidos
	;chamada da função
	mov ah, 3fh
	int 21h
	;testa se chegou no final do arquivo
	cmp ax, cx
	jl endOfFile
	
	;move o conteúdo do arquivo (um caractere apenas) para um registrador
	mov bl, bufferFile
	;incrementa o contador de caracteres lidos
	inc contadorLer
	;compara o caractere com TAB (ASCII 9)
	cmp bl, TAB
	je achouTAB
	;compara o caractere com ESPAÇO (ASCII 20H)
	cmp bl, SPACE
	je trataEspaco
	salvaCaractereString:
	;se o caractere não for TAB nem ESPAÇO, salva ele na string
	mov [di], bl
	;incrementa a posição na string
	inc di
	;zera a flag que indica se já foi achado um espaço
	mov flagEspaco, 0
	;volta para o laço
	jmp proxCaractere
	
	achouTAB:
	;incrementa o contador de caracteres a serem excluídos
	inc contadorExcluir
	;e volta para o laço sem salvar o caractere na string
	jmp proxCaractere
	
	trataEspaco:
	;testa se a flag já está ligada
	cmp flagEspaco, 1
	je flagOn
	;se não, liga a flag
	inc flagEspaco
	;salva o caractere na string
	mov [di], bl
	;incrementa a posição da string
	inc di
	;e volta para o laço
	jmp proxCaractere
	flagOn:
	;se a flag estiver ligada, já foi achado um espaço,
	;então como esse espaço atual é duplicado, apenas incrementamos o contador de caracteres excluídos
	inc contadorExcluir
	;e voltamos para o laço para podermos ler outro caractere
	jmp proxCaractere
	
endOfFile:
	;finalizamos a string com um cifrão ($)
	mov [di], '$'
	;fechar arquivo
	mov ah, 3eh
	mov bx, handlerFile
	int 21h
	
	;move o cursor
	mov dh, 1 ;segunda linha
	mov dl, 0
	mov bh, 0 
	mov ah, 2
	int 10h

	;inicializa o contador
	mov contadorLinha, 80
	;coloca a string num ponteiro para percorrê-la
	lea si, arquivo
	
	percorreString:
	;este laço percorre a string com o conteúdo dod arquivo até achar um \n ou chegar no fim ou achar um espaço
	;move o conteúdo de um caractere para um registrador
	mov al, [si]
	;e incrementa a posição na string
	inc si
	;compara o caractere com espaço
	cmp al, SPACE
	je achouEspaco
	;e compara ele com um indicador de quebra de linha
	cmp al, LF
	je achouLineFeed
	;por fim, compara ele com um indicador de final de texto
	cmp al, 0
	je fimTexto
	;decrementa o contador de quantas colunas já foram preenchidas na tela
	dec contadorLinha
	;se chegou ao final, parte para uma parte do código que lida com a quebra de linha que corta palavras ao meio
	jz fimLinhaFormatada
	;e volta para o laço para lidar com o próximo caractere
	jmp percorreString
	
	achouEspaco:
	;como o código incrementa a posição da string sempre antes de testar os códigos,
	;decrementamos ela aqui
	dec si
	;guardamos a posição do último espaço
	mov guardaEspaco, si
	;e reincrementamos a posição da string
	inc si
	;decrementamos o contador de quantas colunas foram preenchidas na linha
	dec contadorLinha
	jmp percorreString
	
	achouLineFeed:
	;zera o contador se chegar em \n
	mov contadorLinha, 80
	;e incrementamos a posição da string
	inc si
	jmp percorreString
	
	fimLinhaFormatada:
	;aqui também precisamos decrementar a posição para lidarmos com o útlimo caractere que caberia na linha
	dec si
	;comparamos ele com um espaço
	cmp al, SPACE
	;e se ele não for, procuramos o último espaço para forçarmos uma quebra de linha ali
	jne voltaUltimoEspaco
	;reincrementamos a posição da string
	inc si
	;comparamos seu conteúdo (agora um a mais que o número que cabe em uma linha da tela) com espaço
	cmp [si], SPACE
	je primeiroEspaco
	;e redecrementamos sua posição caso não seja um espaço
	dec si
	;reinicializamos o contador de colunas numa linha
	mov contadorLinha, 80
	;e forçamos a quebra de linha
	mov [si], LF
	;antes de voltar para o laço
	jmp percorreString
	
	voltaUltimoEspaco:
	;voltamos para a última posição que continha espaço na string
	mov di, guardaEspaco
	mov bx, guardaEspaco
	;forçamos uma quebra de linha nessa posição
	mov byte ptr [bx], LF
	;reinicializamos o contador de colunas numa linha
	mov contadorLinha, 80
	;incrementamos a posição da string
	inc di
	mov si, di
	;e voltamos para o laço
	jmp percorreString
	
	primeiroEspaco:
	;forçamos uma quebra de linha
	mov byte ptr [si], LF
	;incrementamos a posição da string
	inc si
	;reinicializamos o contador de colunas numa linha
	mov contadorLinha, 80
	;e voltamos para o laço
	jmp percorreString

	fimTexto:
	;imprime toda a string na tela
	lea dx, arquivo
	mov ah, 9
	int 21h
	
	;coloração das primeira e última linhas da tela
	mov ch, 24 		;última linha
	mov cl, 0		
	mov dh, 24		
	mov dl, 79		
	mov bh, 01bh	;fundo azul com letras ciano claro
	mov al, 1		
	;chamada da função
	mov ah, 6		
	int	10h

	;move o cursor
	mov dh, 24 ;move cursor pra ultima linha
	mov dl, 0
	mov bh, 0
	mov ah, 2
	int 10h
	
	;imprime a mensagem de instrução de como voltar a tela inicial
	lea dx, msgESC
	mov ah, 9
	int 21h
	
	mov	ch, 0 		;primeira linha
	mov cl, 0
	mov dh, 0
	mov dl, 79
	mov bh, 01bh 	;fundo azul com letras ciano claro
	mov al, 1
	;chamada da função
	mov ah, 6
	int 10h
	
	;move o cursor
	mov dh, 0 ;move cursor para primeira linha
	mov dl, 0
	mov bh, 0
	mov ah, 2
	int 10h
	
	;imprime as mensagens com o nome do arquivo e a parte textual do header, sem os valores necessários ainda
	lea dx, msgHeaderUm
	mov ah, 9
	int 21h
	lea dx, msgHeaderDois
	mov ah, 9
	int 21h
	
	;começamos a manipular o número total de caracteres lidos do arquivo em uma string,
	;para poder colocar essa informação no header
	lea si, stringLer
	
	;move o cursor
	mov dl, 21 ;número da coluna para que a string fique formatada no espaço adequado no header
	add dl, tamNomeArquivo
	mov dh, 0
	mov bh, 0
	mov ah, 2
	int 10h
	
	;testa se existem mais de mil caracteres lidos do arquivo
	cmp contadorLer, 1000 
	jg maiorQueMil
	jmp menorOuIgualAMil

	maiorQueMil:
	;se o número total de caracteres lidos for maior que mil,
	;testa se existem mais de dois mil caracteres lidos do arquivo
	cmp contadorLer, 2000 
	jg maiorQueDoisMil
	
	;coloca os caracteres 1 (um) e . (ponto final), para fazer a separação de milhar
	mov dl, '1'
	mov ah, 2
	int 21h
	mov dl, '.'
	mov ah, 2
	int 21h
	
	;subtrai mil do contador para poder continuar a adicionar algarismos
	sub contadorLer, 1000
	;e pula para processar as centenas, dezenas e unidades
	jmp menorOuIgualAMil
	
	maiorQueDoisMil:
	;se o número total de caracteres lidos for maior que dois mil,
	;coloca os caracteres 2 (dois) e . (ponto final), para fazer a separação de milhar
	mov dl, '2'
	mov ah, 2
	int 21h
	mov dl, '.'
	mov ah, 2
	int 21h
	
	;subtrai dois mil do contador para poder continuar a adicionar algarismos
	sub contadorLer, 2000
	;e pula para processar as centenas, dezenas e unidades
	jmp menorOuIgualAMil
	
	menorOuIgualAMil:
	;divide o número atual de caracteres lidos por 100, para conseguir o valor do algarismo da centena
	mov ax, contadorLer
	mov bl, 100
	div bl
	
	add al, 48 ;passa o algarismo para o código em ASCII,
	;pois existem 48 códigos antes da contagem de números na tabela ASCII
	mov [si], al ;move esse algarismo para a string de número de caracteres lidos
	inc si
	sub al, 48 ;reverte o processo de transformação do algarismo em seu código ASCII
	
	mul bl
	sub contadorLer, ax ;subtrai a centena do número total de lidos atuais
	
	;faz o mesmo processo que conseguiu o algarismo de centena para conseguir e colocar na string o algarismo de dezena
	mov ax, contadorLer
	mov bl, 10
	div bl
	
	add al, 48
	mov [si], al
	inc si
	sub al, 48
	
	mul bl
	sub contadorLer, ax
	
	;e agora repete esse processo mais uma vez para acharmos o algarismo de unidade
	mov ax, contadorLer
	mov bl, 1
	div bl
	
	add al, 48
	mov [si], al
	inc si
	
	mov al, '$'
	mov [si], al ;por último, finalizamos a string com o cifrão
	
	;terminada a string com o total de caracteres lidos, podemos passar para a manipulação da string de caracteres excluídos
	lea si, stringExcluir
	
	;pelo tamanho dos arquivos, não precisaremos manipular o milhar na string de número de caracteres excluídos
	;então começamos a sequência de divisões pela centena direto, para conseguirmos seu algarismo
	;porém como não sabemos se existem mais de 99 caracteres excluídos, também vamos testar antes se o número é maior que 100
	cmp contadorExcluir, 100
	jl menosDeCem
	
	mov ax, contadorExcluir
	mov bl, 100
	div bl
	
	add al, 48
	mov [si], al
	inc si
	sub al, 48
	
	mul bl
	sub contadorExcluir, ax
	
	;partimos para a casa das dezenas
	menosDeCem:
	mov ax, contadorExcluir
	mov bl, 10
	div bl
	
	add al, 48
	mov [si], al
	inc si
	sub al, 48
	
	mul bl
	sub contadorExcluir, ax
	
	;e por fim as unidades
	mov ax, contadorExcluir
	mov bl, 1
	div bl
	
	add al, 48
	mov [si], al
	inc si
	
	mov al, '$'
	mov [si], al ;e finalizamos esta string também com um cifrão
	
	;imprime no local certo a string com o número de caracteres lidos do arquivo
	lea dx, stringLer
	mov ah, 9
	int 21h
	
	;move o cursor
	mov dl, 42 ;número da coluna para que a string fique formatada certinha no header
	add dl, tamNomeArquivo
	mov dh, 0
	mov bh, 0
	mov ah, 2
	int 10h
	
	;imprime no local certo a string com o número de caracteres excluídos na formatação do arquivo
	lea dx, stringExcluir
	mov ah, 9
	int 21h
	
	;move o cursor para o fim da mensagem de ESC,
	;para não atrapalhar a visão do usuário
	mov dl, 43 ;número certo da coluna para o cursor estar logo após a mensagem
	mov dh, 24 ;última linha da tela
	mov bh, 0
	mov ah, 2
	int 10h
	
trataESC:	
	;espera um caractere ser digitado
	mov ah, 0
	int 16h
	;testa se o caractere é um ESC
	cmp al, ESCAPE
	;se não for, continua esperando
	jne trataESC
	;se for, volta ao início do programa
	jmp etapaUm
	
; retorno ao DOS com codigo de retorno 0 no AL (fim normal)
fim:
	;limpa a tela
	mov ch, 0
	mov cl, 0
	mov dh, 24
	mov dl, 79
	mov bh, 07h
	mov al, 0
	mov ah, 6
	int 10h
	;colore a tela
	mov	ch, 0
	mov cl, 0
	mov dh, 2
	mov dl, 79
	mov bh, 01bh ;fundo azul com letras ciano claro
	mov al, 3
	mov ah, 6
	int 10h
	;move o cursor pro inicio da pagina 
	mov dh, 0
	mov dl, 0
	mov bh, 0 
	mov ah, 2
	int 10h
	;imprime uma mensagem de encerramento
	lea dx, msgEncerramento
	mov ah, 9
	int 21h
    mov ax,4c00h           ; funcao retornar ao DOS no AH
    int 21h                ; chamada do DOS

codigo   ends

; a diretiva a seguir indica o fim do codigo fonte (ultima linha do arquivo)
; e informa que o programa deve começar a execucao no rotulo "inicio"
    end    inicio 