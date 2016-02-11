;****************************************************************************
;*								$$$$$$$$$$$$$$ 	                        	*
;*								$	TEXvid   $								*
;*								$$$$$$$$$$$$$$								*
;*			 			Sistema de interface ....							*
;*																			*
;*			   		Desenvolvido por Ricardo de Azambuja					*
;*																			*
;*		main.asm															*
;*		Vers�o 0.1							Data Inicial: 13/10/2005		*
;*--------------------------------------------------------------------------*
;* DESCRI��O DO ARQUIVO / PROJETO:											*
;* -																		*
;* -																		*
;* - 																		*
;* - 																		*
;* - 																		*
;*--------------------------------------------------------------------------*
;* NOTAS:																	*
;* 1)PINOS UTILIZADOS:
;* -RA6 E RA7 (OSC EXTERNO);RB1 E RB2 (USART ASS�NCRONA)
;* -RB3 E RB5 (SA�DA DO V�DEO COMPOSTO)								        *
;*     -RB3 e RB5 HIGH(1): branco
;*     -RB3 LOW(0) e RB5(1) HIGH: preto
;*     -RB3 LOW(0) e RB5 LOW(0): sincronismo
;* -RA1 (LED INDICADOR DE ERRO NA SERIAL)
;****************************************************************************

;****************************************************************************
;*							ARQUIVOS DE DEFINI��ES							*
;****************************************************************************

#INCLUDE <P16F628A.inc>       ; processor specific variable definitions
;Na fase inicial de testes, feita na placa de testes McLab1, usei o 628 e nao o 628A.
;Na versao final (com serial, etc), foi usado o P16F628A.inc para rodar a 20MHz

	errorlevel 1,-207
	;Desabilita uma warning chata que aparece devido ao codigo da macro

;
	__CONFIG   _CP_OFF & _DATA_CP_OFF & _LVP_OFF & _BOREN_ON & _MCLRE_OFF & _WDT_OFF & _PWRTE_ON & _HS_OSC ;_INTOSC_OSC_NOCLKOUT
; Ver livro Desbravando o PIC p�g 62 para as configura��es ou p�g 98 do datasheet
; Os nomes acima est�o definidos no arquivo .INC
; Essa configura��o pode ser feita pelo programa que vai gravar o processador

;****************************************************************************
;*							PAGINA��O DE MEM�RIA							*
;****************************************************************************
;DEFINI��O DE COMANDOS DE USU�RIO PARA ALTERA��O DA P�GINA DE MEM�RIA
#DEFINE		BANK0	BCF STATUS,RP0 ;SETA BANK 0 DE MEM�RIA
#DEFINE		BANK1	BSF	STATUS,RP0 ;SETA BANK 1 DE MEM�RIA

;A diretriz #DEFINE substitui nomes por express�es inteiras
;(a diretriz EQU substitui nomes por n�meros)



;****************************************************************************
;*								VARI�VEIS									*
;****************************************************************************
;DEFINI��O DOS NOMES E ENDERE�OS DE TODAS AS VARI�VEIS UTILIZADAS PELO SISTEMA
;N�O ESQUECER QUE TODAS ESSAS VARI�VEIS SER�O DE 8BITS
	
	CBLOCK		0x70				;ENDERE�O INICIAL DA MEM�RIA DE USU�RIO (0x70 AT� 0x7F)
									;Coloquei a memoria de usuario no 0x70 para ter uma regiao continua de memoria
									;para ser utilizada na area da armazenagem e geracao da imagem.

				W_TEMP				;REGISTRADORES TEMPOR�RIOS PARA USO (0x70)
				STATUS_TEMP			;JUNTO �S INTERRUP��ES (0x71)

				DELAY				;Usada na macro que gera ciclos para temporizacao (0x72)
				CONT_VERT			;Usada para contar o numero de linhas horizontais que jah foram desenhadas (0x73)
				FLAGS				;Usado para as flags do programa (0x74)
				MARGEM_SUPERIOR		;Numero de linhas apagadas na parte de cima da tela + 14 (usada com LINHA_INICIO) (0x75)
				MARGEM_INFERIOR		;Numero de linhas apagadas na parte de baixo da tela + 14 (usada com LINHA_QUANT) (0x76)
				CONTA_3LINHAS_A		;Conta as tres linhas do video para formar um pixel no TEXVID A(0x77)
				CONTA_3LINHAS_B		;Conta as tres linhas do video para formar um pixel no TEXVID B(0x78)
				CONT_BUFFER			;Contador usado para controlar em qual buffer estou (0x79)
				SALVA_FSR			;Usado para salvar o conteudo do FSR durante a interrup��o da serial (0x7A)
				SALVA_CAR			;Usado para salvar o caractere recebido pela serial (0x7B)

	ENDC							;FIM DO BLOCO DE MEM�RIA


	CBLOCK		0xA0				;ENDERE�O INICIAL DA MEM�RIA DO BANCO 1 (0xA0 AT� 0xEF)
									;Este espa�o de mem�ria � utilizado no tratamento de comandos recebidos
									;pela serial porque n�o havia mais espa�o livre no banco0

				BUFFER0				;Buffers utilizados para guardar os caracteres recebidos ap�s um '@'.
				BUFFER1
				BUFFER2
				BUFFER3
				BUFFER4
				BUFFER5
				BUFFER6
				BUFFER7
				BUFFER8
				BUFFER9
				BUFFERA
				BUFFERB				;No total ser�o 12 caracteres (0xA0 at� 0xAB)
									;Caract 0   : Indica qual a linha que ser� escrita (1 ou 2).
									;Caract 1-12: letra que ser� mostrada na tela.

	ENDC							;FIM DO BLOCO DE MEM�RIA DO BANCO 1
					
;CBLOCK e ENDC: � uma maneira simplificada de definirmos v�rios EQUs com 
;endere�os sequenciais. Assim fica mais f�cil a migra��o para outro processador ou
;para outro bloco de endere�os.


;****************************************************************************
;*							FLAGS INTERNOS									*
;****************************************************************************
;DEFINI��O DE TODOS OS FLAGS UTILIZADOS PELO SISTEMA

#DEFINE			SINC_H	FLAGS,0			;Usado para sinalizar que iniciou uma linha
										;horizontal (apos os pulsos de sincronismo horizontal).
										;INICIA COM ZERO

#DEFINE			SINC_V	FLAGS,1			;Sinaliza quando deve ser feito o sincronismo vertical
										;INICIA COM ZERO

#DEFINE			ODD		FLAGS,2			;Sinaliza se eh o campo par ou impar
										;ODD->1 impar
										;ODD->0 par
										;INICIA COM UM

#DEFINE			TELA	FLAGS,3			;Permite ou nao que seja desenhado algo na tela
										;TELA->1 libera
										;TELA->0 nivel de preto
										;INICIA COM ZERO

#DEFINE			ARROBA	FLAGS,4			;Indica se foi recebido o '@' pela serial
										;ARROBA->0 ainda nao foi recebido
										;ARROBA->1 j� foi recebido
										;INICIA COM ZERO

#DEFINE			EXECUTA	FLAGS,5			;Indica quando devo executar (durante o campo par) o buffer 
										;de comandos recebidos pela serial.
										;EXECUTA->0 n�o executar o buffer de comandos
										;EXECUTA->1 executar os comandos
										;INICIA COM ZERO

;****************************************************************************
;*								CONSTANTES									*
;****************************************************************************
;DEFINI��O DE TODAS AS CONSTANTES UTILIZADAS PELO SISTEMA

INIC_TMR0 		EQU		.102			;Inicializa o TMR0 (Timer0)
										;Inicialmente este valor foi calculado para 63.5uS, mas depois teve de ser
										;ajustado conforme o codigo foi crescendo e se modificando para
										;ser possivel manter o sincronismo com o numero de instrucoes necessario.
										;Uma interrupcao por Timer0 ocorre a cada 64uS

END_INIC_VIDEO	EQU		0x26			;Endereco inicial na RAM onde consta a imagem (vai de 0x26 ateh 0x6E)
END_BASE_LINHA	EQU		0x20			;Endereco inicial onde consta a linha que sera desenhada pelo SAIDABIT.

LINHA_INICIO	EQU		.150			;Numero da linha na qual a imagem deve ser ligada
LINHA_QUANT		EQU		.36				;Numero de linhas que serao ligadas

TAM_PXL			EQU		.5				;Regula a altura do pixel (em numero_de_linhas - 2)
										;Esta nao pode ser mudada sem alterar algumas partes do codigo
										;devido a temporizacao e a falta de ciclos de maquina livres.

END_INIC_CMDS	EQU		0xA0			;Endere�o inicial do buffer de comandos.
END_FIM_CMDS	EQU		0xAB			;Endere�o final do buffer de comandos.

;
;TABELA COM OS CARACTERES USADOS
;
CR				EQU		0x0D ;Retorno de Carro
SP				EQU		0x20 ;Espaco
BS				EQU		0x08 ;Backspace
ESC				EQU		0x1B ;ESC

AR				EQU		0x40 ;@

MA				EQU		0x2B ;+
ME				EQU		0x2D ;-
MU				EQU		0x2A ;*
DV				EQU		0x2F ;/
IG				EQU		0x3D ;=
AP				EQU		0x28 ;(
FP				EQU		0x29 ;)

SI				EQU		0x3F ;?
SE				EQU		0x21 ;!
PT				EQU		0x2E ;.
DP				EQU		0x3A ;:

	CBLOCK 			0x30
				ZR ;0
				UM ;1
				DO ;2
				TR ;3
				QU ;4
				CN ;5
				SZ ;6
				ST ;7
				OI ;8
				NO ;9
	ENDC

	CBLOCK			0x41 	;Caracteres de A a Z em ASCII
				AA
				BB
				CC
				DD
				EE
				FF
				GG
				HH
				II
				JJ
				KK
				LL
				MM
				NN
				OO
				PP
				QQ
				RR
				SS
				TT
				UU
				VV
				WW
				XX
				YY
				ZZ
	ENDC					;Para os caracteres min�sculos, � s� somar 32decimal ou 20hexa.




;****************************************************************************
;*								MACROS     									*
;****************************************************************************

;Esta macro foi necess�ria para facilitar a manuten��o do c�digo fonte.
;Sem uma macro, esse conjunto de instru��es seria repetido para cada bit lido
;tornando o arquivo fonte dificil de editar e de visualizar.
;
;
;SAIDABIT
;Gera o c�digo necess�rio para a leitura de um bit da mem�ria RAM
;e posterior escrita no pino definido por saida.
; - ENDERECO_INI: endere�o inicial da RAM onde esta a linha que ser� lida.
; - ENDERECO_FIN: endere�o final (se for ler um soh byte, fica igual ao inicial).
; - NBIT    : n�mero de bits a serem lidos no total (assim n�o preciso ler bytes inteiros)
;             *** lembrar que caso sejam lidos dois bytes, p.ex., NBIT fica 16!!!!
; - ROTULO  : r�tulo inicial para servir como endere�o base na mem�ria de programa.
SAIDABIT	MACRO	ENDERECO_INI, ENDERECO_FIN, NBIT, ROTULO
				VARIABLE	i=0							;Define uma vari�vel para o compilador
														;N�O ESTAR� PRESENTE NO CODIGO DE PROGRAMA!
				VARIABLE	it=0						;Usada para medir o total de bits
				VARIABLE	ENDERECO=ENDERECO_INI

				WHILE (ENDERECO<=ENDERECO_FIN) && (it<NBIT)
					WHILE (i<8) && (it<NBIT)
						btfss		ENDERECO,i
						goto		ROTULO+(6*(it+1))-2
						;SETA PINO
						bsf			saida				;Seta o pino de sa�da pra 1 (nivel de branco)
						goto		ROTULO+(6*(it+1))	;"M�gica" usada para pular para as linhas corretas 
														;ROTULO_INICIAL + NUMERO_DE_INSTRUCOES_DA_MACRO*BITS_LIDOS
						;LIMPA PINO
						bcf			saida				;Seta o pino de sa�da pra 0 (nivel de preto)
						nop
					i++
					it++
	
					ENDW ;fim do 2� while
				i=0
				ENDERECO++
				ENDW ;fim do 1� while
			ENDM

;NOPS 
;Gera um delay de TEMPO ciclos.
;Devido ao arredondamento, nem sempre o no. de ciclos eh igual a TEMPO.
;Porem, a funcao economiza memoria de programa, por nao inserir um monte de NOPs, 
; e nao custa nada calcular e depois colocar uns poucos nop's, se necessario.
NOPS	MACRO	TEMPO

		movlw		.256-(TEMPO/3)
		movwf		DELAY
		incfsz		DELAY,F
		goto		$-0x01

		ENDM


;****************************************************************************
;*								ENTRADAS									*
;****************************************************************************
;DEFINI��O DE TODOS OS PINOS QUE SER�O UTILIZADOS COMO ENTRADA
;COM OS SEUS ESTADOS COMENTADOS (0 E 1)

;Este sistema nao utiliza pinos de entrada jah que uso o PowerOnReset, BrownOut
;e deixo o pino de MasterClear livre para uso futuro.

;Quaisquer comandos necessarios ao sistema serao inseridos via serial.

;****************************************************************************
;*									SA�DAS									*
;****************************************************************************
;DEFINI��O DE TODOS OS PINOS QUE SER�O UTILIZADOS COMO SA�DA

#DEFINE			saida		PORTB,5		;Sa�da principal de v�deo
										;- 1 para branco
										;- 0 para preto

#DEFINE			sincronismo PORTB,3		;Usado para gerar o sincronismo em conjunto
										;com o pino saida
										;saida-0 e sincronismo-0: sinal de sincronismo (0V:-40IRE)
										;saida-0 e sincronismo-1: nivel de preto (0.3V:7.5IRE)
										;saida-1 e sincronismo-1: nivel de branco (1V:100IRE)

;Os pinos saida e sincronismo estao ligados entre si por resistores (cfe. esquematico) para funcionarem
;como um DA de 2bits gerando os sinais 0V, 0.3V e 1V quando ligados a uma carga de 75Ohms (entrada TVs).


#DEFINE			LED_OERR	PORTA,1		;Define o pino do led que indicar� o erro no recebimento
										;da serial.										
										;- 1 apagado (normal)
										;- 0 aceso (erro overrun no recebimento)

#DEFINE			LED_SEROK	PORTB,4		;Indica que uma linha de comando est� aberta.
#DEFINE			LED_SERERR	PORTB,6		;Indica que ocorreu um erro.

;****************************************************************************
;*								VETOR DE RESET								*
;****************************************************************************
	ORG 		0x00				;ENDERE�O INICIAL DE PROCESSAMENTO
	GOTO 		INICIO



;****************************************************************************
;*						IN�CIO DAS INTERRUP��ES								*
;****************************************************************************
;ENDERE�OS DE DESVIO DAS INTERRUP��ES, A PRIMEIRA TAREFA � SALVAR OS VALORES
;DE "W" E "STATUS" PARA RECUPERA��O FUTURA. ASSIM NAO HA O RISCO DE DANIFICAR ALGO.

	ORG 		0x04				;ENDERE�O INICIAL DAS INTERRUP��ES
	MOVWF		W_TEMP				;COPIA W PARA W_TEMP
	SWAPF 		STATUS,0
	MOVWF		STATUS_TEMP			;COPIA STATUS PARA STATUS_TEMP


;@@@@@@@@@@@@@@@@@@@@@@@@@   INICIO DE UM PULSO   @@@@@@@@@@@@@@@@@@@@@@@@@@@
;SINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINC
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;Inicia a borda preta do sincronismo para economizar tempo
	;Tempo aprox. 1.4uS
	bcf			saida
	;Inicio da contagem de tempo
	;1 ciclo

;****************************************************************************
;*							ROTINA DE INTERRUP��O							*
;****************************************************************************
;AQUI SER�O ESCRITAS AS ROTINAS DE RECONHECIMENTO E TRATAMENTO DAS INTERRUP��ES
;No PIC16F628A, para sabermos qual foi a interrup��o que ocorreu deve-se fazer
;um tratamento por software (polling).

	btfsc		INTCON,T0IF			;Testa se interrup��o foi do TMR0
	goto		INT_TIMER0

	btfsc		PIR1,RCIF			;Testa se interrup��o foi por recebimento serial
	goto		INT_SERIAL

	goto		SAI_INT				;Este comando nao eh necessario, mas...
									;nao custa ser prevenido.

;
;
;Tratamento da interrup��o por estouro do Timer0
;
;4 ciclos
INT_TIMER0
	bcf			INTCON,T0IF			;Limpa o bit que foi setado pelo estouro do TMR0
	movlw		INIC_TMR0
	movwf		TMR0				;Recarrega o TMR0
	;7 ciclos @ 20MHz = 1.4us

;@@@@@@@@@@@@@@@@@@@@@@@@@   INICIO DE UM PULSO   @@@@@@@@@@@@@@@@@@@@@@@@@@@
;SINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINC
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;Neste ponto, termina a borda preta do inicio do pulso horizontal
	;e comeca o pulso de sincronismo.
	bcf			sincronismo
	;Inicio do pulso de 4.8uS no nivel de sincronismo
	;24 ciclos.
	;NOPS .24
	;
	;Codigo usado para ligar ou desligar linhas na imagem.
	;Eh feito um teste com a contagem de linhas atuais e a margem superior. Se a contagem
	;das linhas atuais tiver ultrapassado o valor da margem superior, liga a imagem.
	movfw		MARGEM_SUPERIOR
	bcf			STATUS,0			;Seta o C (se ele for 0, negativo)
	subwf		CONT_VERT,W			;Subtrai MARGEM_SUPERIOR de CONT_VERT e armazena em W.
	btfsc		STATUS,0			;Testa se o resultado acima foi menor que zero.
	goto		DESENHA_TELA1		;Menor que zero
	goto		NAO_DESENHA_TELA1	;Maior ou igual a zero
NAO_DESENHA_TELA1
	clrf		CONTA_3LINHAS_A		;Garante o sincronismo entre a memoria e 
	clrf		CONTA_3LINHAS_B		;o inicio do desenho na tela.
	bcf			TELA				;Desativa a saida de imagem
	goto		FIM_DESENHA_TELA1	
DESENHA_TELA1
	bsf			TELA				;Ativa a saida de imagem	
	nop								;Para manter o mesmo numero de ciclos
	nop								;que o caso NAO_DESENHA_TELA1
	nop
FIM_DESENHA_TELA1
	movfw		MARGEM_INFERIOR		;Verifica se jah ultrapassou o limite inferior.
	bcf			STATUS,0			;Seta o Carry (se ele for 0, no. negativo)
	subwf		CONT_VERT,W
	btfsc		STATUS,0
	bcf			TELA	

;Codigo usado para repetir uma linha de memoria de imagem 3X na tela. Assim consigo "pixels" com
;a altura de 3 linhas de video.
;Ele tambem faz o servico de ler da memoria de imagem e colocar na memoria de linha.
	decfsz		CONTA_3LINHAS_A,F
	goto		CONTINUA_NA_MESMA_LINHA1
	
	movfw		INDF
	movwf		END_BASE_LINHA
	incf		FSR,F							;A primeira ocorrencia desta linha deve ter sido precedida
												;em algum pto do codigo pela carga do FSR com o endereco
												;inicial da memoria da imagem.
	movfw		INDF
	movwf		END_BASE_LINHA + 1
	incf		FSR,F

	goto		CONTINUA_SINCRONISMO1			;Para nao estragar o sincronismo, tive de quebrar a rotina em duas.

CONTINUA_NA_MESMA_LINHA1
	btfss		CONTA_3LINHAS_A,7				;Se for um, significa que CONTA_3LINHAS virou.
	goto		CONTINUA_NA_MESMA_LINHA1_SR		;Tenho que cuidar se for feita alteracao do codigo acima,
												;porque posso perder essa informacao. Ou seja, nao posso mudar
												;o registrador STATUS sem salvar antes.
	movlw		TAM_PXL
	movwf		CONTA_3LINHAS_A					;Recarrega o contador
	nop
	goto		CONTINUA_SINCRONISMO1

CONTINUA_NA_MESMA_LINHA1_SR
	nop
	nop
	nop
	nop
	;fim do pulso de 4.8uS (24 ciclos@20MHz)

CONTINUA_SINCRONISMO1

;@@@@@@@@@@@@@@@@@@@@@@@@@   INICIO DE UM PULSO   @@@@@@@@@@@@@@@@@@@@@@@@@@@
;SINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINCSINC
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	bsf			sincronismo
	;Inicio do pulso de 4.8uS no nivel de preto (24 ciclos@20MHz)
	;Aqui eu utilizaria 24 ciclos, mas como sao gastos 8 ciclos para
	;sair da interrupcao do timer0 diminuo aqui.

	decfsz		CONTA_3LINHAS_B,F
	goto		CONTINUA_NA_MESMA_LINHA2
	
	movfw		INDF
	movwf		END_BASE_LINHA + 2
	incf		FSR,F

	movfw		INDF
	movwf		END_BASE_LINHA + 3
	incf		FSR,F

	movfw		INDF
	movwf		END_BASE_LINHA + 4
	incf		FSR,F

	movfw		INDF
	movwf		END_BASE_LINHA + 5
	incf		FSR,F
	goto		CONTINUA_SINCRONISMO2

CONTINUA_NA_MESMA_LINHA2
	btfss		CONTA_3LINHAS_B,7				;Se for um, significa que CONTA_3LINHAS virou.
	goto		CONTINUA_NA_MESMA_LINHA2_SR		;Tenho que cuidar se for feita alteracao do codigo acima,
												;porque posso perder essa informacao.
	
	movlw		TAM_PXL
	movwf		CONTA_3LINHAS_B					;Recarrega o contador
;	NOPS .7
	nop
	;
	btfss		TELA							;Resolve o problema da contagem errada
	movlw		TAM_PXL-.4						;na primeira linha apos a MARGEM_SUPERIOR
	btfss		TELA
	movwf		CONTA_3LINHAS_A
	btfss		TELA
	movwf		CONTA_3LINHAS_B
	;
	goto		CONTINUA_SINCRONISMO2

CONTINUA_NA_MESMA_LINHA2_SR						;O SR eh de S_em R_ecarregar o contador
	NOPS .10 ;10 ciclos

CONTINUA_SINCRONISMO2

	incfsz		CONT_VERT,f			;Conta ateh 242 e depois sinaliza
	goto		SEM_SINCV_AINDA
	bsf			SINC_V				;que eh hora da sincronia vertical

SEM_SINCV_AINDA

	bsf			SINC_H					;Ativa a saida de imagem

	goto		SAI_INT ;2 ciclos

;#####################################################################################
;						TRATAMENTO DA INTERRUPCAO DA SERIAL
;#####################################################################################
;Tratamento da interrup��o devido � recep��o pela Serial
;
;A utilizacao de um buffer de comandos faz com que a serial n�o prejudique a gera��o
;dos pulsos de sincronismo.
;Ap�s o buffer de comandos ter sido finalizado com um CR, fica liberado o processamento
;utilizando o tempo livre da tela em branco (campo par).

INT_SERIAL
	bcf    		PIR1,RCIF    		;Limpa o RCIF Interrupt Flag.
	movf		RCREG,W				;Carregou o conteudo recebido no W.
	clrf		RCREG				;Limpa o RCREG para poder receber o prox byte e n�o correr risco de erro.
	bcf			LED_OERR			;Desliga o led indicador de erro na serial.

;A PARTIR DESSE PTO ACREDITO QUE POSSO MUDAR PARA O BANCO1 SEM PROBLEMAS, POIS O
;REGISTRADOR STATUS TEM UMA SOMBRA NO BANCO1 E A MEMORIA DE PROGRAMA (0x70 AT� 0x7F) TAMB�M.


NIVEL_UM
;S� passo para um n�vel adiante se receber o '@' indicando o in�cio de um conjunto de comandos.
;Com esse sistema, posso ficar aguardando quanto tempo for necess�rio para receber uma linha
;de comandos completa. Assim n�o prejudico a gera��o de sincronismo.

	btfsc		ARROBA				;Testa se j� recebi um '@' pela serial e, portanto,
									;que iniciar� uma linha de comandos.

	goto		NIVEL_CMDS			;Passa para o n�vel de recebimento de comandos.
	

	;Teste para verificar se recebi um '@'.
	bcf			STATUS,2			;Limpa o Z.
	xorlw		AR					;Codigo ASCII para o '@'.
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		RECEBI_ARROBA		;Se o Z foi para 1, recebi o '@'.
	call		LEDERR				;Indica que n�o recebeu a letra correta.
	goto		CONTINUA_SERIAL		;Segue adiante esperando a pr�xima interrup��o.

	
RECEBI_ARROBA
	call 		LEDOK				;Indica que iniciou uma linha de comando.
	bsf			ARROBA				;Indica que recebi um '@'
	bcf			EXECUTA				;Desliga a execu��o de comandos.

	movlw		END_INIC_CMDS		;Inicializa o contador do buffer com o endere�o inicial
	movwf		CONT_BUFFER			;do buffer de comandos (que se encontra no banco 1).

	goto		CONTINUA_SERIAL		;Segue adiante esperando a pr�xima interrup��o.

NIVEL_CMDS
;Se recebi um arroba, come�o a guardar no buffer de comandos tudo o que for recebido.
;Caso receba um CR, preencho o resto do buffer com espa�os em branco.
;Caso receba um ESC, esque�o tudo e seto ARROBA com zero.

	;Teste para verificar se recebi um 'CR'.
	bcf			STATUS,2			;Limpa o Z.
	xorlw		CR					;Codigo ASCII para o 'CR'.
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto 		RECEBEU_CR			;Se o Z foi para 1, recebi o 'CR'.
	xorlw		CR					;Se o Z nao foi para 1, desfaz o XOR.

	;Teste para verificar se recebi um 'ESC'.
	bcf			STATUS,2			;Limpa o Z.
	xorlw		ESC					;Codigo ASCII para o 'ESC'.
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto 		RECEBEU_ESC			;Se o Z foi para 1, recebi o 'ESC'.
	xorlw		ESC					;Se o Z nao foi para 1, desfaz o XOR.


	;Inicia o preenchimento do buffer com comandos
	BANK1							;Troca para o banco de mem�ria RAM No 1 para conseguir mais
									;espa�o livre.

	movwf		SALVA_CAR			;Salva o caractere recebido pela serial
									;que estava armazenado no W.

	movfw		FSR					;Salva o conte�do do registrador FSR
	movwf		SALVA_FSR			;para n�o danificar a gera��o de imagem.
	
	movfw		CONT_BUFFER
	movwf		FSR					;Carrega o FSR com o endere�o do buffer de comando

	movfw		SALVA_CAR			;Recarrega o caractere recebido no W.
	movwf		INDF				;Coloca o caractere recebido no endereco CONT_BUFFER do buffer.

	incf		CONT_BUFFER,F		;Incrementa o endere�o.
	
	;Testa se j� alcan�ou o �ltimo endere�o do buffer de comandos.
	movfw		CONT_BUFFER			;Carrega o �ltimo endere�o calculado.
	bcf			STATUS,2			;Limpa o Z.
	xorlw		END_FIM_CMDS+0x01	;Testa se � igual ao �ltimo endere�o do buffer + 1.
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto 		ACABOU_CMDS			;Se o Z foi para 1, acabou.
	goto		CONTINUA_CMDS		;Se o Z nao foi para 1, continua recebendo comandos.

ACABOU_CMDS
	BANK0							;Volta para o banco0.
	bcf 		LED_SEROK			;Indica desligando o led.
	bcf			ARROBA				;Libera o recebimento de outra linha de comandos.
	bsf			EXECUTA				;Indica que uma linha de comandos est� pronta pra execu��o.

CONTINUA_CMDS
	BANK0							;Volta para o banco0.
	movfw		SALVA_FSR			;Restaura o conte�do do registrador FSR
	movwf		FSR					;para n�o danificar a gera��o de imagem.

	goto		CONTINUA_SERIAL		;Segue adiante esperando a pr�xima interrup��o.

RECEBEU_CR
	;Inicia o preenchimento do resto do buffer de comando com espa�os em branco.
	BANK1							;Troca para o banco de mem�ria RAM No 1 para conseguir mais
									;espa�o livre.

	movfw		FSR					;Salva o conte�do do registrador FSR
	movwf		SALVA_FSR			;para n�o danificar a gera��o de imagem.
	
	movfw		CONT_BUFFER
	movwf		FSR					;Carrega o FSR com o endere�o do buffer de comando

LOOP_RECEBEU_CR

	movlw		SP					;Coloca o valor ASCII do espa�o no W.
	movwf		INDF				;Coloca o W no endereco CONT_BUFFER do buffer.

	incf		CONT_BUFFER,F		;Incrementa o endere�o.
	
	;Testa se j� alcan�ou o �ltimo endere�o do buffer de comandos.
	movfw		CONT_BUFFER			;Carrega o �ltimo endere�o calculado.
	bcf			STATUS,2			;Limpa o Z.
	xorlw		END_FIM_CMDS+0x01	;Testa se � igual ao �ltimo endere�o do buffer + 1.
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto 		ACABOU_CMDS			;Se o Z foi para 1, acabou.
	goto		LOOP_RECEBEU_CR		;Se o Z nao foi para 1, continua preenchendo com espa�os.

RECEBEU_ESC
	bcf 		LED_SEROK			;Indica desligando o led.
	bcf			ARROBA				;Libera o recebimento de outra linha de comandos
									;e com isso sobrescreve a atual.


CONTINUA_SERIAL
	btfsc		RCSTA,OERR			;Testa se houve erro na recep��o (overrun error)
	goto		ERRO_OERR

	goto		SAI_INT


;Tratamento do Overrun Error e acendimento / apagamento do led indicativo
ERRO_OERR
	bsf			LED_OERR			;Acende o led que s� ser� apagado no pr�ximo caractere recebido.
	
	bcf			RCSTA,CREN			;Desliga o bit OERR (ele � ligado por hardware)
	bcf			RCSTA,CREN			;Note que para desligar o OERR � necess�rio
									;desligar e ligar o CREN (que ativa o recebimento.

	goto 		SAI_INT

;O bit OERR deve ser limpo por software.


;****************************************************************************
;*							ROTINA DE SA�DA DA INTERRUP��O					*
;****************************************************************************
;OS VALORES DE "W" E "STATUS" DEVEM SER RECUPERADOS ANTES DE RETORNAR DA INTERRUP��O

SAI_INT
;Restaura os registradores W e STATUS ao estado que estavam antes da interrupcao.
	SWAPF		STATUS_TEMP,0
	MOVWF		STATUS				;MOVE STATUS_TEMP PARA STATUS
	SWAPF		W_TEMP,1
	SWAPF		W_TEMP,0			;MOVE W_TEMP PARA W
	RETFIE							;RETORNA DA INTERRUP��O (VER ESQUEMA LIVRO P�G 135)
	;Este pequeno trecho consome 6 ciclos que, no final das contas, 
	;totalizam 9 ciclos.

;OBSERVA��ES: 
;- A utiliza��o de SWAPF ao inv�s de MOVF evita a altera��o do STATUS.
;- No in�cio do tratamento da interrup��o, a chave geral � desligada automaticamente
;e depois do RETFIE ela � religada.

;****************************************************************************
;*							ROTINAS E SUBROTINAS							*
;****************************************************************************
;CADA ROTINA OU SUBROTINA DEVE POSSUIR A DESCRI��O DE FUNCIONAMENTO E UM
;NOME COERENTE �S SUAS FUN��ES

LEDOK
	bsf 		LED_SEROK
	bcf			LED_SERERR	
	return

LEDERR
	bsf			LED_SERERR
	bcf			LED_SEROK
	return

;****************************************************************************
;*							IN�CIO DO PROGRAMA								*
;****************************************************************************

INICIO

	BANK0							;TROCA PARA O BANCO DE MEM�RIA 0
	CLRF		PORTA				;LIMPA O PORTA
	CLRF		PORTB				;LIMPA O PORTB

	BANK1							;TROCA PARA O BANCO DE MEM�RIA 1
	MOVLW		B'00000000'
	MOVWF		TRISA				;DEFINE ENTRADAS E SA�DAS DO PORT A
	MOVLW		B'00000110'
	MOVWF		TRISB				;DEFINE ENTRADAS E SA�DAS DO PORT B
									;Bits 1 e 2 referentes a USART
	MOVLW		B'00000000'
	MOVWF		OPTION_REG			;DEFINE OP��ES DE OPERA��O
									;ver pag 25 do datasheet

	MOVLW		B'00000000'
	MOVWF		INTCON				;DEFINE OP��ES DE INTERRUP��ES
									;ver pag 26 do datasheet

;MEU SETUP
;Aqui s�o configurados os registrados especiais (SFR) para o funcionamento correto do sistema
;Para mais informa��es sobre os bits dos SFRs, ver livro p�g 193
	BANK0
	movlw		.0
	movwf		TMR0				;Inicializa o TMR0 com ZERO
									;Para que ele nao estoure antes de 
									;terminar as configuracoes.

	;Setup para recep��o pela USART ass�ncrona.
	;A configura��o ser� feita para 2400-8N1.
	;Baud-Rate 2400, 8 bits de dados, sem paridade e um stop-bit.
	BANK1
	movlw		.129				;Carrega o valor para
	movwf		SPBRG				;setar o BaudRate da USART para 2400@20MHz
									;e erro de 0.16%
	bcf			TXSTA, SYNC			;Habilita a Porta Serial Ass�ncrona
	bcf			TXSTA, BRGH			;Seta para Low Speed Baud

	BANK0							
	bsf			RCSTA, SPEN			;
	bcf			RCSTA, RX9D			;Desabilita a recep��o de 9bits (usada para o CRC por software).
	bsf			RCSTA, CREN			;Habilita a recep��o.

	BANK1
	bsf			PIE1, RCIE			;Habilita a interrup��o de recep��o
	;Fim do setup da serial


	BANK1
	bcf			OPTION_REG,T0CS 	;Seta o TMR0 para o timer mode - incrementa a cada ciclo de clock
;	bsf			OPTION_REG,PSA		;Ativa o Prescaler para o WDT fazendo com que o TIMER0 fique 1:1
	bcf			OPTION_REG,PSA		;Ativa o Prescaler para o TIMER0
	bcf			OPTION_REG,PS2		;Seta como 1:2-000
	bcf			OPTION_REG,PS1
	bcf			OPTION_REG,PS0
		

	bsf			INTCON,	T0IE		;Habilita a interrup��o do TMR0
	bsf			INTCON, PEIE		;Habilita as interrup��es dos perif�ricos.
	bsf			INTCON,	GIE			;Ativa as interrup��es

	BANK0

	bcf			STATUS,IRP			;Habilita o uso de INDF com os bancos 0 e 1.					

;Fim do MEU SETUP


;****************************************************************************
;*							INICIALIZA��O DAS VARI�VEIS						*
;****************************************************************************

	movlw		.14
	movwf		CONT_VERT			;Inicializa o contador de linhas
									;para conseguir contar 242 linhas

	;Nao esquecer que o valor minimo desses caras eh .14
	;A area util do sistema inicia com MARGEM_SUPERIOR=50
;	movlw		.50					;Valor Minimo
	movlw		LINHA_INICIO
	movwf		MARGEM_SUPERIOR

;	movlw		.242				;Valor Maximo
	movlw		2*LINHA_QUANT + LINHA_INICIO
	movwf		MARGEM_INFERIOR

	movlw		TAM_PXL				;Inicializa os contadores que geram um pixel com 3 linhas
	movwf		CONTA_3LINHAS_A
	movwf		CONTA_3LINHAS_B

	;Carrega o primeiro endereco de onde esta a imagem que ser colocada na tela
	;Tenho que cuidar porque nao posso mais usar o FSR em outro lugar sem salva-lo e
	;depois restaura-lo.
	movlw		END_INIC_VIDEO		;Inicia o FSR com o primeiro
	movwf		FSR					;endereco da memoria de video.


	bcf			SINC_H				;Para que a imagem soh comece depois do
									;TIMER0 ter estourado uma primeira vez.

	bsf			ODD					;O primeiro campo eh impar.
	
	bcf			SINC_V				;Nunca comeca com sincronismo vertical.

	bcf			TELA				;Inicia com tela preta.

	bcf			ARROBA				;Inicia indicando que n�o foi recebido o '@' pela serial.

	bcf			EXECUTA				;Inicia indicando para n�o executar o buffer de comandos.

	bcf			LED_OERR			;Inicia o programa com o led limpo (apagado) para OK

	bcf			LED_SEROK			;Inicia com zero

	bcf			LED_SERERR			;Inicia com zero

;****************************************************************************
;*							CORPO DA ROTINA PRINCIPAL						*
;****************************************************************************

MAIN
	;CORPO DA ROTINA PRINCIPAL

	;CARREGA A IMAGEM NA MEMORIA RAM - DEBUG
	call		CARREGA_IMAGEM

SEM_SINC_H
	btfss		SINC_H
	goto		SEM_SINC_H

	btfsc		SINC_V
	goto		SINCRONISMO_VERTICAL

	bcf			saida						;Garante as linhas pares apagadas

	btfss		ODD
	goto		SEM_SINC_H

	nop										;Importante para manter o sincronismo
	nop										;Tenho que procurar onde esta faltando esse tempo
;A imagem deve estar armazenada na memoria para ser lida
;conforme eh feito abaixo (cada vez que for escrita uma linha)

	btfss		TELA						;Testa se posso desenhar
	goto		FIM_DA_IMAGEM				;algo na tela
;Inicio da leitura da imagem da memoria
INICIO_DA_IMAGEM

bit00
	SAIDABIT 0x20,0x25,48,bit00				;soh os primeiros 45 ptos sao visiveis na tela
	nop

;Fim da leitura da imagem da memoria
FIM_DA_IMAGEM
	nop										;Importante para manter o sincronismo
	nop										;Tenho que procurar onde esta faltando esse tempo
	nop
	nop
	bcf			SINC_H
	goto 		SEM_SINC_H

SINCRONISMO_VERTICAL

;PRIMEIRA EQUALIZACAO
;Sao tres linhas com seis pulsos de sincronizacao

	;Primeira linha - H1
	;P1.1
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bcf			saida
	bcf			sincronismo
	;NOPS		.24 ;25 ciclos
	NOPS		.20	;19 ciclos

	movlw		TAM_PXL				;Recarrega o contador de linhas
	movwf		CONTA_3LINHAS_A		;usado para criar os meus pixels
	movwf		CONTA_3LINHAS_B		;usado para criar os meus pixels

	nop
	nop
	nop

	
	;P2.1
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bsf			sincronismo
	bcf			INTCON,T0IE			;Desabilita a interrup��o do TMR0
									;para que ele nao estoure no meio de V_SINC
	;NOPS		.134 ;133 ciclos

	movlw		END_INIC_VIDEO		;Recarrega o endereco inicial da memoria
	movwf		FSR					;que eu utilizo para armazenar a imagem

	;Como o FSR jah foi recarregado, agora preciso recarregar o endereco inicial
	;da linha, ou seja, tenho que carregar a primeira linha no END_BASE_LINHA em diante
	movfw		INDF
	movwf		END_BASE_LINHA + 0
	incf		FSR,F

	movfw		INDF
	movwf		END_BASE_LINHA + 1
	incf		FSR,F

	movfw		INDF
	movwf		END_BASE_LINHA + 2
	incf		FSR,F

	movfw		INDF
	movwf		END_BASE_LINHA + 3
	incf		FSR,F

	movfw		INDF
	movwf		END_BASE_LINHA + 4
	incf		FSR,F

	movfw		INDF
	movwf		END_BASE_LINHA + 5
	incf		FSR,F

	movlw		END_INIC_VIDEO		;Recarrega o endereco inicial da memoria
	movwf		FSR					;que eu utilizo para armazenar a imagem
	
	NOPS .17 ;16 ciclos
	nop
	nop

	;P1.2
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bcf			sincronismo
	NOPS		.25
	
	;P2.2
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bsf			sincronismo
	NOPS		.135

	;Segunda linha - H2
	;P1.1
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bcf			sincronismo
	NOPS		.25
	
	;P2.1
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bsf			sincronismo
	NOPS		.135

	;P1.2
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bcf			sincronismo
	NOPS		.25
	
	;P2.2
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bsf			sincronismo
	NOPS		.135

	;Terceira linha - H3
	;P1.1
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bcf			sincronismo
	NOPS		.25
	
	;P2.1
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bsf			sincronismo
	NOPS		.135

	;P1.2
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bcf			sincronismo
	NOPS		.25
	
	;P2.2
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bsf			sincronismo
	NOPS		.135
;FIM DA PRIMEIRA EQUALIZACAO



;SINCRONISMO
;Sao tres linhas com seis pulsos de sincronizacao, mas invertidos

	;Primeira linha - H4
	;P1.1
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bcf			sincronismo
	NOPS		.135

	;P2.1
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bsf			sincronismo
	NOPS		.25
	
	;P1.2
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bcf			sincronismo
	NOPS		.135

	;P2.2
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bsf			sincronismo
	NOPS		.25

	;Segunda linha - H5
	;P1.1
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bcf			sincronismo
	NOPS		.135

	;P2.1
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bsf			sincronismo
	NOPS		.25
	
	;P1.2
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bcf			sincronismo
	NOPS		.135

	;P2.2
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bsf			sincronismo
	NOPS		.25

	;Terceira linha - H6
	;P1.1
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bcf			sincronismo
	NOPS		.135

	;P2.1
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bsf			sincronismo
	NOPS		.25
	
	;P1.2
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bcf			sincronismo
	NOPS		.135

	;P2.2
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bsf			sincronismo
	NOPS		.25
;FIM DO SINCRONISMO

;SEGUNDA EQUALIZACAO
;Sao tres linhas com seis pulsos de sincronizacao

	;Primeira linha - H7
	;P1.1
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bcf			sincronismo
	NOPS		.25
	
	;P2.1
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bsf			sincronismo
	NOPS		.135

	;P1.2
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bcf			sincronismo
	NOPS		.25
	
	;P2.2
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bsf			sincronismo
	NOPS		.135

	;Segunda linha - H8
	;P1.1
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bcf			sincronismo
	NOPS		.25
	
	;P2.1
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bsf			sincronismo
	NOPS		.135

	;P1.2
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bcf			sincronismo
	NOPS		.25
	
	;P2.2
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bsf			sincronismo
	NOPS		.135

	;Terceira linha - H9
	;P1.1
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bcf			sincronismo
	NOPS		.25
	
	;P2.1
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bsf			sincronismo
	NOPS		.135

	;P1.2
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bcf			sincronismo
	NOPS		.25
	
	;P2.2
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bsf			sincronismo
	NOPS		.120				;135 - 15(abaixo) = 120
;FIM DA SEGUNDA EQUALIZACAO

	bcf			SINC_V				;Limpa a chave da interrupcao horizontal
	;Num primeiro momento vou fazer todo o campo par com nivel de preto
	;ou seja, 12 linhas do final do sincronismo + 242 = 254 linhas

	btfsc		ODD
	goto		PAR
	goto		IMPAR

PAR
	bcf			ODD
	movlw		.2					;Normalmente eh com 14, mas agora quero
	movwf		CONT_VERT			;contar tambem as linhas de retraco vertical
	goto		CONTINUA_SINC_VERT

IMPAR
	bsf			ODD
	movlw		.14					
	movwf		CONT_VERT			
	nop								;Para mante-los simetricos

CONTINUA_SINC_VERT

	;Como a sincronizacao eh muito grande, o TMR0 deve ter estourado e 
	;com isso setado o T0IF. Portanto, assim que eu religar a interrupcao
	;ele vai pular para 0x04.
	movlw		INIC_TMR0+5
	movwf		TMR0				;Recarrega o TMR0
	bcf			INTCON,T0IF			;Limpa o bit que foi setado pelo estouro do TMR0
	bsf			INTCON,T0IE			;Desabilita a interrup��o do TMR0
									;para que ele nao estoure no meio de V_SINC

	bcf			TELA				;Para que soh seja desenhado algo depois da interrupcao
	goto		SEM_SINC_H



;##############################################################################
;    IMAGEM INICIAL QUE APARECERA NA TELA ASSIM QUE O SISTEMA FOR LIGADO
;##############################################################################
;Nao esquecer que os bits sao lidos do LSB -> MSB. Ex. 'abcdefgh'
;sera escrito na tela como: hgfedcba
CARREGA_IMAGEM

;LEMBRAR QUE A MEMORIA DISPONIVEL PARA AS IMAGENS VAI DE:
;0x26
;ate
;0x6F (
;Depois o que for gravado ira sobrepor as variaveis do sistema.
	

	VARIABLE   LINHA=0

	;INICIA COM TUDO ZERO PARA NAO OCORRER DISTORCOES EM ALGUNS
	;TIPOS DE APARELHOS DE TELEVISAO.
	;Outro motivo para a distorcao eh que fui obrigado a inserir codigos
	;extras no meio dos sincronismos, mas esses codigos soh sao executados
	;na primeira linha (bits) lida da memoria.
	movlw		B'00000000'	
	movwf		END_INIC_VIDEO + .0
	movwf		END_INIC_VIDEO + .1
	movwf		END_INIC_VIDEO + .2
	movwf		END_INIC_VIDEO + .3
	movwf		END_INIC_VIDEO + .4
	movwf		END_INIC_VIDEO + .5
	;6 bytes (nao devem ser modificados)


	LINHA=0x06
	;linha 1/5
	movlw		B'01110111'	
	movwf		END_INIC_VIDEO + LINHA + .0
	movlw		B'00000101'	
	movwf		END_INIC_VIDEO + LINHA + .1
	movlw		B'00000000'		
	movwf		END_INIC_VIDEO + LINHA + .2
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .3
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .4
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .5
	;linha 2/5
	movlw		B'00010010'
	movwf		END_INIC_VIDEO + LINHA + .6
	movlw		B'01010101'
	movwf		END_INIC_VIDEO + LINHA + .7
	movlw		B'00001101'		
	movwf		END_INIC_VIDEO + LINHA + .8
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .9
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .10
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .11
	;linha 3/5
	movlw		B'00110010'
	movwf		END_INIC_VIDEO + LINHA + .12
	movlw		B'01010010'
	movwf		END_INIC_VIDEO + LINHA + .13
	movlw		B'00010100'		
	movwf		END_INIC_VIDEO + LINHA + .14
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .15
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .16
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .17

	;linha 4/5
	movlw		B'00010010'
	movwf		END_INIC_VIDEO + LINHA + .18
	movlw		B'01010101'
	movwf		END_INIC_VIDEO + LINHA + .19
	movlw		B'00010101'		
	movwf		END_INIC_VIDEO + LINHA + .20
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .21
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .22
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .23

	;linha 5/5
	movlw		B'01110010'
	movwf		END_INIC_VIDEO + LINHA + .24
	movlw		B'00100101'
	movwf		END_INIC_VIDEO + LINHA + .25
	movlw		B'00001101'		
	movwf		END_INIC_VIDEO + LINHA + .26
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .27
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .28
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .29
	;30 bytes

	;TUDO ZERO
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .30
	movwf		END_INIC_VIDEO + LINHA + .31
	movwf		END_INIC_VIDEO + LINHA + .32
	movwf		END_INIC_VIDEO + LINHA + .33
	movwf		END_INIC_VIDEO + LINHA + .34
	movwf		END_INIC_VIDEO + LINHA + .35
	;6 bytes (nao devem ser modificados)


	;
	;LINHA 2
	;
	LINHA=LINHA+0x1E+0x06
	;linha 1/5
	movlw		B'01110111'	
	movwf		END_INIC_VIDEO + LINHA + .0
	movlw		B'00000101'	
	movwf		END_INIC_VIDEO + LINHA + .1
	movlw		B'00000000'		
	movwf		END_INIC_VIDEO + LINHA + .2
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .3
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .4
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .5
	;linha 2/5
	movlw		B'00010010'
	movwf		END_INIC_VIDEO + LINHA + .6
	movlw		B'01010101'
	movwf		END_INIC_VIDEO + LINHA + .7
	movlw		B'00001101'		
	movwf		END_INIC_VIDEO + LINHA + .8
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .9
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .10
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .11
	;linha 3/5
	movlw		B'00110010'
	movwf		END_INIC_VIDEO + LINHA + .12
	movlw		B'01010010'
	movwf		END_INIC_VIDEO + LINHA + .13
	movlw		B'00010100'		
	movwf		END_INIC_VIDEO + LINHA + .14
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .15
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .16
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .17

	;linha 4/5
	movlw		B'00010010'
	movwf		END_INIC_VIDEO + LINHA + .18
	movlw		B'01010101'
	movwf		END_INIC_VIDEO + LINHA + .19
	movlw		B'00010101'		
	movwf		END_INIC_VIDEO + LINHA + .20
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .21
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .22
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .23

	;linha 5/5
	movlw		B'01110010'
	movwf		END_INIC_VIDEO + LINHA + .24
	movlw		B'00100101'
	movwf		END_INIC_VIDEO + LINHA + .25
	movlw		B'00001101'		
	movwf		END_INIC_VIDEO + LINHA + .26
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .27
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .28
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINHA + .29
	;30 bytes

	;Memoria total consumida: 6 + 30 + 6 + 30 = 72 bytes
	;Considerando os 6 bytes usados pela funcao SAIDABIT, ficam 78 bytes.


	return

;****************************************************************************
;*							FIM DO PROGRAMA									*
;****************************************************************************


	END							;INDICA O FIM DO ARQUIVO C�DIGO-FONTE
	

;Modelo de estrutura��o de c�dido baseado no exemplo do livro "Desbravando o PIC"
