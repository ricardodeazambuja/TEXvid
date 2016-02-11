;****************************************************************************
;*								$$$$$$$$$$$$$$ 	                        	*
;*								$	TEXvid   $								*
;*								$$$$$$$$$$$$$$								*
;*			 			Sistema de interface ....							*
;*																			*
;*			   		Desenvolvido por Ricardo de Azambuja					*
;*																			*
;*		main.asm															*
;*		Versão 0.1							Data Inicial: 13/10/2005		*
;****************************************************************************
;****$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$****
;****************************************************************************
;*																			*
;* ESTE PROGRAMA É PROTEGIDO PELAS LEIS DE DIREITOS AUTORAIS, NÃO SENDO		*
;* PERMITIDA A CÓPIA, DIVULGAÇÃO OU A UTILIZAÇÃO EM/POR QUAISQUER MEIOS 	*
;* SEM A EXPRESSA AUTORIZAÇÃO DO AUTOR.										*
;*                                                                          *
;****************************************************************************
;****$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$****
;****************************************************************************
;*--------------------------------------------------------------------------*
;* DESCRIÇÃO DO ARQUIVO / PROJETO:											*
;* -																		*
;* -																		*
;* - 																		*
;* - 																		*
;* - 																		*
;*--------------------------------------------------------------------------*
;* NOTAS:																	*
;* 1)PINOS UTILIZADOS:
;* -RA6 E RA7 (OSC EXTERNO);RB1 E RB2 (USART ASSÍNCRONA)
;* -RB3 E RB5 (SAÍDA DO VÍDEO COMPOSTO)								        *
;*     -RB3 e RB5 HIGH(1): branco
;*     -RB3 LOW(0) e RB5(1) HIGH: preto
;*     -RB3 LOW(0) e RB5 LOW(0): sincronismo
;* -RA1 (LED INDICADOR DE ERRO NA SERIAL)
;****************************************************************************

;****************************************************************************
;*							ARQUIVOS DE DEFINIÇÕES							*
;****************************************************************************

#INCLUDE <P16F628A.inc>       ; processor specific variable definitions
;Na fase inicial de testes, feita na placa de testes McLab1, usei o 628 e nao o 628A.
;Na versao final (com serial, etc), foi usado o P16F628A.inc para rodar a 20MHz

	errorlevel 1,-207
	;Desabilita uma warning chata que aparece devido ao codigo da macro

;
	__CONFIG   _CP_OFF & _DATA_CP_OFF & _LVP_OFF & _BOREN_ON & _MCLRE_OFF & _WDT_OFF & _PWRTE_ON & _HS_OSC ;_INTOSC_OSC_NOCLKOUT
; Ver livro Desbravando o PIC pág 62 para as configurações ou pág 98 do datasheet
; Os nomes acima estão definidos no arquivo .INC
; Essa configuração pode ser feita pelo programa que vai gravar o processador

;****************************************************************************
;*							PAGINAÇÃO DE MEMÓRIA							*
;****************************************************************************
;DEFINIÇÃO DE COMANDOS DE USUÁRIO PARA ALTERAÇÃO DA PÁGINA DE MEMÓRIA
#DEFINE		BANK0	BCF STATUS,RP0 ;SETA BANK 0 DE MEMÓRIA
#DEFINE		BANK1	BSF	STATUS,RP0 ;SETA BANK 1 DE MEMÓRIA

;A diretriz #DEFINE substitui nomes por expressões inteiras
;(a diretriz EQU substitui nomes por números)



;****************************************************************************
;*								VARIÁVEIS									*
;****************************************************************************
;DEFINIÇÃO DOS NOMES E ENDEREÇOS DE TODAS AS VARIÁVEIS UTILIZADAS PELO SISTEMA
;NÃO ESQUECER QUE TODAS ESSAS VARIÁVEIS SERÃO DE 8BITS
	
	CBLOCK		0x70				;ENDEREÇO INICIAL DA MEMÓRIA DE USUÁRIO (0x70 ATÉ 0x7F)
									;Coloquei a memória de usuário no 0x70 para ter uma região contínua de memória
									;para ser utilizada na área da armazenagem e geração da imagem.

				W_TEMP				;REGISTRADORES TEMPORÁRIOS PARA USO (0x70)
				STATUS_TEMP			;JUNTO ÀS INTERRUPÇÕES (0x71)

				DELAY				;Usada na macro que gera ciclos para temporização (0x72)
				CONT_VERT			;Usada para contar o numero de linhas horizontais que já foram desenhadas (0x73)
				FLAGS				;Usado para as flags do programa (0x74)
				MARGEM_SUPERIOR		;Numero de linhas apagadas na parte de cima da tela + 14 (usada com LINHA_INICIO) (0x75)
				MARGEM_INFERIOR		;Numero de linhas apagadas na parte de baixo da tela + 14 (usada com LINHA_QUANT) (0x76)
				CONTA_3LINHAS_A		;Conta as três linhas do vídeo para formar um pixel no TEXVID A(0x77)
				CONTA_3LINHAS_B		;Conta as três linhas do vídeo para formar um pixel no TEXVID B(0x78)
				CONT_BUFFER			;Contador usado para controlar em qual buffer estou (0x79)
				SALVA_FSR			;Usado para salvar o conteúdo do FSR durante a interrupção da serial (0x7A)
				SALVA_CAR			;Usado para salvar o caractere recebido pela serial (0x7B)
				SALVA_FSR2			;Usado para salvar o conteúdo do FSR durante a execução dos comandos (0x7C)
				ENDERECO_INICIAL	;Indica o endereço inicial da primeira ou da segunda linha na execução dos cmds (0x7D)
				CONT_BUFFER2		;Contador usado para passar os caracteres pra tela na ordem correta (0x7E)
				ENDERECO_LETRA		;Indica o endereço inicial da primeira ou da segunda linha na execução dos cmds (0x7F)
									;ACABOU A MEMÓRIA DO 0x70 até o 0x7F!!!!

	ENDC							;FIM DO BLOCO DE MEMÓRIA


	CBLOCK		0x20				;ENDEREÇO INICIAL DA MEMÓRIA DE LINHA NO BANCO 0 (0x20 ATÉ 0x25)
									;Neste espaço de memória ficam armazenados os bits correspondentes
									;a próxima linha de imagem (não confundir c/ caracteres) gerada 
									;após o sincronismo horizontal e desenhadas usando a macro SAIDABIT.


				END_BASE_LINHA		;Endereco inicial onde consta a linha que sera desenhada(0x20).


	ENDC							;FIM DO BLOCO DE MEMÓRIA DE LINHA NO BANCO 0



	CBLOCK		0x26				;ENDEREÇO INICIAL DA MEMÓRIA DE IMAGEM NO BANCO 0 (0x26 ATÉ 0x6E)
									;Este espaço é usado para guardar as duas linhas de texto (ou gráfico)
									;que serão enviadas para a tela.

				END_INIC_VIDEO		;Endereco inicial na RAM onde consta a imagem (0x26)


	ENDC							;FIM DO BLOCO DE MEMÓRIA DE IMAGEM NO BANCO 0




	CBLOCK		0xA0				;ENDEREÇO INICIAL DO BUFFER DE COMANDOS NO BANCO 1 (0xA0 ATÉ 0xEF)
									;Este espaço de memória é utilizado no tratamento de comandos recebidos
									;pela serial porque não havia mais espaço livre no banco0

				END_INIC_CMDS		;Endereço inicial do buffer de comandos (0xA0).
				BUFFER1
				BUFFER2				;Todos estes buffers são utilizados para guardar
				BUFFER3				;os caracteres recebidos após um '@'.
				BUFFER4
				BUFFER5
				BUFFER6
				BUFFER7
				BUFFER8
				BUFFER9
				BUFFERA
				END_FIM_CMDS		;Endereço final do buffer de comandos (0xAB).

									;No total serão 12 caracteres (0xA0 até 0xAB)
									;Caract 0   : Indica qual a linha que será escrita (1 ou 2).
									;Caract 1-12: letra que será mostrada na tela.

	ENDC							;FIM DO BLOCO DE MEMÓRIA DO BUFFER DE COMANDOS NO BANCO 1


	CBLOCK		0xAC				;Armazena, temporariamente, o desenho da letra no formato binário.

				LETRA1
				LETRA2
				LETRA3
				LETRA4
				LETRA5
	ENDC
					
;CBLOCK e ENDC: é uma maneira simplificada de definirmos vários EQUs com 
;endereços sequenciais. Assim fica mais fácil a migração para outro processador ou
;para outro bloco de endereços.


;****************************************************************************
;*							FLAGS INTERNOS									*
;****************************************************************************
;DEFINIÇÃO DE TODOS OS FLAGS UTILIZADOS PELO SISTEMA

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
										;ARROBA->1 já foi recebido
										;INICIA COM ZERO

#DEFINE			EXECUTA	FLAGS,5			;Indica quando devo executar (durante o campo par) o buffer 
										;de comandos recebidos pela serial.
										;EXECUTA->0 não executar o buffer de comandos
										;EXECUTA->1 executar os comandos
										;INICIA COM ZERO

#DEFINE			MEIOBYTE FLAGS,6		;Indica se estou nos LSBs ou nos MSBs.
										;É usada na conversão dos caracteres recebidos pela serial.
										;MEIOBYTE->0 LSB
										;MEIOBYTE->1 MSB
										;INICIA COM ZERO

#DEFINE			SPLASH	FLAGS,7			;Indica se foi mostrada a splahwindow
										;SPLASH->0 não foi
										;SPLASH->1 foi mostrada
										;INICIA COM ZERO

;****************************************************************************
;*								CONSTANTES									*
;****************************************************************************
;DEFINIÇÃO DE TODAS AS CONSTANTES UTILIZADAS PELO SISTEMA

INIC_TMR0 		EQU		.102			;Inicializa o TMR0 (Timer0)
										;Inicialmente este valor foi calculado para 63.5uS, mas depois teve de ser
										;ajustado conforme o codigo foi crescendo e se modificando para
										;ser possivel manter o sincronismo com o numero de instrucoes necessario.
										;Uma interrupcao por Timer0 ocorre a cada 64uS

LINHA_INICIO	EQU		.150			;Numero da linha na qual a imagem deve ser ligada
LINHA_QUANT		EQU		.36				;Numero de linhas que serao ligadas

TAM_PXL			EQU		.5				;Regula a altura do pixel (em numero_de_linhas - 2)
										;Esta nao pode ser mudada sem alterar algumas partes do codigo
										;devido a temporizacao e a falta de ciclos de maquina livres.

;
;TABELA COM OS CARACTERES USADOS
;
CR				EQU		0x0D ;Retorno de Carro
LF				EQU		0x0A ;LineFeed
SP				EQU		0x20 ;Espaco
BS				EQU		0x08 ;Backspace
ESC				EQU		0x1B ;ESC
DOLAR			EQU		0x24 ;$
ECOMER			EQU		0x26 ;&

AR				EQU		0x40 ;@

;Abaixo são os caracteres que serão mostrados na tela.
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
PO				EQU		0X25 ;%
SU				EQU		0X23 ;#
AS				EQU		0X22 ;"

	CBLOCK 			0x30
				ZR   ;0
				UM   ;1
				DO   ;2
				TR   ;3
				QU   ;4
				CI   ;5
				SZ   ;6
				ST   ;7
				OI   ;8
				NO   ;9
	ENDC

	CBLOCK			0x41 	;Caracteres de A a Z em ASCII
				AA ;(0x41) ou (0x61)
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
				ZZ ;(0x5A) ou (0x7A)
	ENDC					;Para os caracteres minúsculos, é só somar 32decimal ou 20hexa.




;****************************************************************************
;*								MACROS     									*
;****************************************************************************

;Esta macro foi necessária para facilitar a manutenção do código fonte.
;Sem uma macro, esse conjunto de instruções seria repetido para cada bit lido
;tornando o arquivo fonte dificil de editar e de visualizar.
;
;
;SAIDABIT
;Gera o código necessário para a leitura de um bit da memória RAM
;e posterior escrita no pino definido por saida.
; - ENDERECO_INI: endereço inicial da RAM onde esta a linha que será lida.
; - ENDERECO_FIN: endereço final (se for ler um soh byte, fica igual ao inicial).
; - NBIT    : número de bits a serem lidos no total (assim não preciso ler bytes inteiros)
;             *** lembrar que caso sejam lidos dois bytes, p.ex., NBIT fica 16!!!!
; - ROTULO  : rótulo inicial para servir como endereço base na memória de programa.
SAIDABIT	MACRO	ENDERECO_INI, ENDERECO_FIN, NBIT, ROTULO
				VARIABLE	i=0							;Define uma variável para o compilador
														;NÃO ESTARÁ PRESENTE NO CODIGO DE PROGRAMA!
				VARIABLE	it=0						;Usada para medir o total de bits
				VARIABLE	ENDERECO=ENDERECO_INI

				WHILE (ENDERECO<=ENDERECO_FIN) && (it<NBIT)
					WHILE (i<8) && (it<NBIT)
						btfss		ENDERECO,i
						goto		ROTULO+(6*(it+1))-2
						;SETA PINO
						bsf			saida				;Seta o pino de saída pra 1 (nivel de branco)
						goto		ROTULO+(6*(it+1))	;"Mágica" usada para pular para as linhas corretas 
														;ROTULO_INICIAL + NUMERO_DE_INSTRUCOES_DA_MACRO*BITS_LIDOS
						;LIMPA PINO
						bcf			saida				;Seta o pino de saída pra 0 (nivel de preto)
						nop
					i++
					it++
	
					ENDW ;fim do 2° while
				i=0
				ENDERECO++
				ENDW ;fim do 1° while
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
;DEFINIÇÃO DE TODOS OS PINOS QUE SERÃO UTILIZADOS COMO ENTRADA
;COM OS SEUS ESTADOS COMENTADOS (0 E 1)

;Este sistema nao utiliza pinos de entrada jah que uso o PowerOnReset, BrownOut
;e deixo o pino de MasterClear livre para uso futuro.

;Quaisquer comandos necessarios ao sistema serao inseridos via serial.

;****************************************************************************
;*									SAÍDAS									*
;****************************************************************************
;DEFINIÇÃO DE TODOS OS PINOS QUE SERÃO UTILIZADOS COMO SAÍDA

#DEFINE			saida		PORTB,5		;Saída principal de vídeo
										;- 1 para branco
										;- 0 para preto

#DEFINE			sincronismo PORTB,3		;Usado para gerar o sincronismo em conjunto
										;com o pino saida
										;saida-0 e sincronismo-0: sinal de sincronismo (0V:-40IRE)
										;saida-0 e sincronismo-1: nivel de preto (0.3V:7.5IRE)
										;saida-1 e sincronismo-1: nivel de branco (1V:100IRE)

;Os pinos saida e sincronismo estao ligados entre si por resistores (cfe. esquematico) para funcionarem
;como um DA de 2bits gerando os sinais 0V, 0.3V e 1V quando ligados a uma carga de 75Ohms (entrada TVs).


#DEFINE			LED_SEROK	PORTB,7		;Indica que uma linha de comando está aberta.
#DEFINE			LED_SERERR	PORTB,6		;Indica que ocorreu um erro.
#DEFINE			LED_OERR	PORTB,4		;Define o pino do led que indicará o erro no recebimento
#DEFINE			LED_DEBUG	PORTB,0		;usado para debug apenas

;****************************************************************************
;*								VETOR DE RESET								*
;****************************************************************************
	ORG 		0x00				;ENDEREÇO INICIAL DE PROCESSAMENTO
	GOTO 		INICIO



;****************************************************************************
;*						INÍCIO DAS INTERRUPÇÕES								*
;****************************************************************************
;ENDEREÇOS DE DESVIO DAS INTERRUPÇÕES, A PRIMEIRA TAREFA É SALVAR OS VALORES
;DE "W" E "STATUS" PARA RECUPERAÇÃO FUTURA. ASSIM NAO HA O RISCO DE DANIFICAR ALGO.

	ORG 		0x04				;ENDEREÇO INICIAL DAS INTERRUPÇÕES
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
;*							ROTINA DE INTERRUPÇÃO							*
;****************************************************************************
;AQUI SERÃO ESCRITAS AS ROTINAS DE RECONHECIMENTO E TRATAMENTO DAS INTERRUPÇÕES
;No PIC16F628A, para sabermos qual foi a interrupção que ocorreu deve-se fazer
;um tratamento por software (polling).

	btfsc		INTCON,T0IF			;Testa se interrupção foi do TMR0
	goto		INT_TIMER0

	btfsc		PIR1,RCIF			;Testa se interrupção foi por recebimento serial
	goto		INT_SERIAL

	goto		SAI_INT				;Este comando nao eh necessario, mas...
									;nao custa ser prevenido.

;
;
;Tratamento da interrupção por estouro do Timer0
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
;Tratamento da interrupção devido à recepção pela Serial
;
;A utilizacao de um buffer de comandos faz com que a serial não prejudique a geração
;dos pulsos de sincronismo.
;Após o buffer de comandos ter sido finalizado com um CR, fica liberado o processamento
;utilizando o tempo livre da tela em branco (campo par).

INT_SERIAL
	bcf    		PIR1,RCIF    		;Limpa o RCIF Interrupt Flag.
	movf		RCREG,W				;Carregou o conteudo recebido no W.
	clrf		RCREG				;Limpa o RCREG para poder receber o prox byte e não correr risco de erro.
	bcf			LED_OERR			;Desliga o led indicador de erro na serial.

	movwf		SALVA_CAR			;Salva o caractere recebido pela serial.

	movfw		FSR					;Salva o conteúdo do registrador FSR
	movwf		SALVA_FSR			;para não danificar a geração de imagem.


;A PARTIR DESSE PTO ACREDITO QUE POSSO MUDAR PARA O BANCO1 SEM PROBLEMAS, POIS O
;REGISTRADOR STATUS TEM UMA SOMBRA NO BANCO1 E A MEMORIA DE PROGRAMA (0x70 ATÉ 0x7F) TAMBÉM.


NIVEL_UM
;Só passo para um nível adiante se receber o '@' indicando o início de um conjunto de comandos.
;Com esse sistema, posso ficar aguardando quanto tempo for necessário para receber uma linha
;de comandos completa. Assim não prejudico a geração de sincronismo.
	
	movfw		SALVA_CAR			;Restaura o caractere recebido pela serial no W.

	btfsc		ARROBA				;Testa se já recebi um '@' pela serial e, portanto,
									;que iniciará uma linha de comandos.

	goto		NIVEL_CMDS			;Passa para o nível de recebimento de comandos.
	

	;Teste para verificar se recebi um '@'.
	bcf			STATUS,2			;Limpa o Z.
	xorlw		AR					;Codigo ASCII para o '@'.
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		RECEBI_ARROBA		;Se o Z foi para 1, recebi o '@'.
	call		LEDERR				;Indica que não recebeu a letra correta.
	goto		CONTINUA_SERIAL		;Segue adiante esperando a próxima interrupção.

	
RECEBI_ARROBA
	call 		LEDOK				;Indica que iniciou uma linha de comando.
	bsf			ARROBA				;Indica que recebi um '@'
	bcf			EXECUTA				;Desliga a execução de comandos.

	movlw		END_INIC_CMDS		;Inicializa o contador do buffer com o endereço inicial
	movwf		CONT_BUFFER			;do buffer de comandos (que se encontra no banco 1).

	goto		CONTINUA_SERIAL		;Segue adiante esperando a próxima interrupção.

NIVEL_CMDS
;Se recebi um arroba, começo a guardar no buffer de comandos tudo o que for recebido.
;Caso receba um CR, preencho o resto do buffer com espaços em branco.
;Caso receba um ESC, esqueço tudo e seto ARROBA com zero.

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
	
	movfw		CONT_BUFFER			;Este contador deve manter o seu valor enquanto não tiver acabado o
									;recebimento dos comandos pelo buffer.
	movwf		FSR					;Carrega o FSR com o endereço do buffer de comando

	movfw		SALVA_CAR			;Recarrega o caractere recebido no W.
	movwf		INDF				;Coloca o caractere recebido no endereco CONT_BUFFER do buffer.

	incf		CONT_BUFFER,F		;Incrementa o endereço.
	
	;Testa se já alcançou o último endereço do buffer de comandos.
	movfw		CONT_BUFFER			;Carrega o último endereço calculado.
	bcf			STATUS,2			;Limpa o Z.
	xorlw		END_FIM_CMDS+0x01	;Testa se é igual ao último endereço do buffer + 1.
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto 		ACABOU_CMDS			;Se o Z foi para 1, acabou.
	goto		CONTINUA_CMDS		;Se o Z nao foi para 1, continua recebendo comandos.

ACABOU_CMDS
	bcf 		LED_SEROK			;Indica desligando o led.
	bcf			ARROBA				;Libera o recebimento de outra linha de comandos.
	bsf			EXECUTA				;Indica que uma linha de comandos está pronta pra execução.
	clrf		CONT_BUFFER			;Zera o contador

CONTINUA_CMDS
	movfw		SALVA_FSR			;Restaura o conteúdo do registrador FSR
	movwf		FSR					;para não danificar a geração de imagem.

	goto		CONTINUA_SERIAL		;Segue adiante esperando a próxima interrupção.

RECEBEU_CR
	;Inicia o preenchimento do resto do buffer de comando com espaços em branco.
	
	movfw		CONT_BUFFER
	movwf		FSR					;Carrega o FSR com o endereço do buffer de comando

	movlw		SP					;Coloca o valor ASCII do espaço no W.
	movwf		INDF				;Coloca o W no endereco CONT_BUFFER do buffer.

	incf		CONT_BUFFER,F		;Incrementa o endereço.
	
	;Testa se já alcançou o último endereço do buffer de comandos.
	movfw		CONT_BUFFER			;Carrega o último endereço calculado.
	bcf			STATUS,2			;Limpa o Z.
	xorlw		END_FIM_CMDS+0x01	;Testa se é igual ao último endereço do buffer + 1.
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto 		ACABOU_CMDS			;Se o Z foi para 1, acabou.
	goto		RECEBEU_CR			;Se o Z nao foi para 1, continua preenchendo com espaços.

RECEBEU_ESC
	bcf 		LED_SEROK			;Indica desligando o led.
	bcf			ARROBA				;Libera o recebimento de outra linha de comandos
									;e com isso sobrescreve a atual.


CONTINUA_SERIAL
	btfsc		RCSTA,OERR			;Testa se houve erro na recepção (overrun error)
	goto		ERRO_OERR

	goto		SAI_INT


;Tratamento do Overrun Error e acendimento / apagamento do led indicativo
ERRO_OERR
	bsf			LED_OERR			;Acende o led que só será apagado no próximo caractere recebido.
	
	bcf			RCSTA,CREN			;Desliga o bit OERR (ele é ligado por hardware)
									;Note que para desligar o OERR é necessário
									;desligar e ligar o CREN (que ativa o recebimento.

	goto 		SAI_INT

;O bit OERR deve ser limpo por software.


;****************************************************************************
;*							ROTINA DE SAÍDA DA INTERRUPÇÃO					*
;****************************************************************************
;OS VALORES DE "W" E "STATUS" DEVEM SER RECUPERADOS ANTES DE RETORNAR DA INTERRUPÇÃO

SAI_INT
;Restaura os registradores W e STATUS ao estado que estavam antes da interrupcao.
	SWAPF		STATUS_TEMP,0
	MOVWF		STATUS				;MOVE STATUS_TEMP PARA STATUS
	SWAPF		W_TEMP,1
	SWAPF		W_TEMP,0			;MOVE W_TEMP PARA W
	RETFIE							;RETORNA DA INTERRUPÇÃO (VER ESQUEMA LIVRO PÁG 135)
	;Este pequeno trecho consome 6 ciclos.

;OBSERVAÇÕES: 
;- A utilização de SWAPF ao invés de MOVF evita a alteração do STATUS.
;- No início do tratamento da interrupção, a chave geral é desligada automaticamente
;e depois do RETFIE ela é religada.

;****************************************************************************
;*							ROTINAS E SUBROTINAS - PEQUENAS					*
;****************************************************************************
;CADA ROTINA OU SUBROTINA DEVE POSSUIR A DESCRIÇÃO DE FUNCIONAMENTO E UM
;NOME COERENTE ÀS SUAS FUNÇÕES

LEDOK
	bsf 		LED_SEROK
	bcf			LED_SERERR	
	return

LEDERR
	bsf			LED_SERERR
	bcf			LED_SEROK
	return

;****************************************************************************
;*							INÍCIO DO PROGRAMA								*
;****************************************************************************

INICIO

	BANK0							;TROCA PARA O BANCO DE MEMÓRIA 0
	CLRF		PORTA				;LIMPA O PORTA
	CLRF		PORTB				;LIMPA O PORTB

	BANK1							;TROCA PARA O BANCO DE MEMÓRIA 1
	MOVLW		B'00000000'
	MOVWF		TRISA				;DEFINE ENTRADAS E SAÍDAS DO PORT A

	MOVLW		B'00000110'
	MOVWF		TRISB				;DEFINE ENTRADAS E SAÍDAS DO PORT B
									;Bits 1 e 2 referentes a USART
	MOVLW		B'00000000'
	MOVWF		OPTION_REG			;DEFINE OPÇÕES DE OPERAÇÃO
									;ver pag 25 do datasheet

	MOVLW		B'00000000'
	MOVWF		INTCON				;DEFINE OPÇÕES DE INTERRUPÇÕES
									;ver pag 26 do datasheet

;MEU SETUP
;Aqui são configurados os registrados especiais (SFR) para o funcionamento correto do sistema
;Para mais informações sobre os bits dos SFRs, ver livro pág 193 ou datasheet.
	BANK0
	movlw		.0
	movwf		TMR0				;Inicializa o TMR0 com ZERO
									;Para que ele nao estoure antes de 
									;terminar as configuracoes.

	;Setup para recepção pela USART assíncrona.
	;A configuração será feita para 2400-8N1.
	;Baud-Rate 2400, 8 bits de dados, sem paridade e um stop-bit.
	BANK1
	movlw		.129				;Carrega o valor para
	movwf		SPBRG				;setar o BaudRate da USART para 2400@20MHz
									;e erro de 0.16%
	bcf			TXSTA, SYNC			;Habilita a Porta Serial Assíncrona
	bcf			TXSTA, BRGH			;Seta para Low Speed Baud

	BANK0							
	bsf			RCSTA, SPEN			;
	bcf			RCSTA, RX9D			;Desabilita a recepção de 9bits (usada para o CRC por software).
	bsf			RCSTA, CREN			;Habilita a recepção.

	BANK1
	bsf			PIE1, RCIE			;Habilita a interrupção de recepção
	;Fim do setup da serial


	BANK1
	bcf			OPTION_REG,T0CS 	;Seta o TMR0 para o timer mode - incrementa a cada ciclo de clock
;	bsf			OPTION_REG,PSA		;Ativa o Prescaler para o WDT fazendo com que o TIMER0 fique 1:1
	bcf			OPTION_REG,PSA		;Ativa o Prescaler para o TIMER0
	bcf			OPTION_REG,PS2		;Seta como 1:2->000
	bcf			OPTION_REG,PS1
	bcf			OPTION_REG,PS0
		

	bsf			INTCON,	T0IE		;Habilita a interrupção do TMR0
	bsf			INTCON, PEIE		;Habilita as interrupções dos periféricos.
	bsf			INTCON,	GIE			;Ativa as interrupções

	BANK0

	bcf			STATUS,IRP			;Habilita o uso de INDF com os bancos 0 e 1.
									;Deste modo tenho um acesso contínuo da memória
									;dos bancos 1 e 2 utilizando FSR e INDF.

;Fim do MEU SETUP


;****************************************************************************
;*							INICIALIZAÇÃO DAS VARIÁVEIS						*
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

	;Carrega o primeiro endereço de onde esta a imagem que ser colocada na tela
	;Tenho que cuidar porque não posso mais usar o FSR em outro lugar sem salva-lo e
	;depois restaurá-lo.
	movlw		END_INIC_VIDEO		;Inicia o FSR com o primeiro
	movwf		FSR					;endereço da memória de vídeo.


	bcf			SINC_H				;Para que a imagem só comece depois do
									;TIMER0 ter estourado uma primeira vez.

	bsf			ODD					;O primeiro campo eh impar.
	
	bcf			SINC_V				;Nunca comeca com sincronismo vertical.

	bcf			TELA				;Inicia com tela preta.

	bcf			ARROBA				;Inicia indicando que não foi recebido o '@' pela serial.

	bcf			EXECUTA				;Inicia indicando para não executar o buffer de comandos.

	bcf 		MEIOBYTE			;Inicia no LSB.

	bcf			SPLASH				;Inicia indicando que não ocorreu a splash.

	bcf			LED_OERR			;Inicia com zero (apagado).

	bcf			LED_SEROK			;Inicia com zero (apagado).

	bcf			LED_SERERR			;Inicia com zero (apagado).

;****************************************************************************
;*							CORPO DA ROTINA PRINCIPAL						*
;****************************************************************************

MAIN
	;CORPO DA ROTINA PRINCIPAL

	;Carrega a 'SplashWindow' na memória RAM.
	call		SPLASHWINDOW

;Fica em loop aguardando o sincronismo horizontal.
;Ou, melhor, o estouro do TMR0.
SEM_SINC_H
	btfss		SINC_H						;Testa se já ocorreu o sincronismo horizontal.
	goto		SEM_SINC_H

	btfsc		SINC_V						;Testa se esse é um sincronismo vertical
	goto		SINCRONISMO_VERTICAL

	bcf			saida						;Garante as linhas pares apagadas

	btfss		ODD							;Testa se é o campo par ou ímpar.
	goto		EXECUTA_COMANDOS			;Aproveito o tempo livre do campo par para
											;processar os comandos recebidos pela serial.
											;Não foi possível usar um call aqui, porque eu
											;teria que colocar mais um teste depois para saltar pro SEM_SINC_H.

	nop										;Importante para manter o sincronismo
	nop										;

;A imagem deve estar armazenada na memória para ser lida
;conforme é feito abaixo (cada vez que for escrita uma linha).

	btfss		TELA						;Testa se a tela foi liberada para que eu
	goto		FIM_DA_IMAGEM				;posso desenhar algo nela.

;Inicio da leitura da imagem da memoria
INICIO_DA_IMAGEM

bit00
	SAIDABIT 0x20,0x25,48,bit00				;soh os primeiros 45 ptos sao visiveis na tela
	nop

;Fim da leitura da imagem da memoria
FIM_DA_IMAGEM
	nop										;Importante para manter o sincronismo
	nop										;
	nop
	nop
	bcf			SINC_H						;Após o desenho da linha, garante que só vai desenhar
	goto 		SEM_SINC_H					;outra linha após o sincronismo horizontal.



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
	bcf			INTCON,T0IE			;Desabilita a interrupção do TMR0
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
	bsf			INTCON,T0IE			;Habilita a interrupção do TMR0
									;para que ele nao estoure no meio de V_SINC

	bcf			TELA				;Para que soh seja desenhado algo depois da interrupcao
	goto		SEM_SINC_H



;##############################################################################
;    IMAGEM INICIAL QUE APARECERA NA TELA ASSIM QUE O SISTEMA FOR LIGADO
;##############################################################################
;Nao esquecer que os bits sao lidos do LSB -> MSB. Ex. 'abcdefgh'
;sera escrito na tela como: hgfedcba
;Se sobrar tempo vou alterar isso, ficou muito chato pra desenhar os caracteres.
SPLASHWINDOW

	bsf		SPLASH				;Indica que ocorreu uma SplashWindow.

;LEMBRAR QUE A MEMÓRIA DISPONÍVEL PARA AS IMAGENS VAI DE:
;0x26
;até
;0x6F
;Depois o que for gravado irá sobrepor as variáveis do sistema.
	

	VARIABLE   LINE=0

	;INICIA COM TUDO ZERO PARA NAO OCORRER DISTORCOES EM ALGUNS
	;TIPOS DE APARELHOS DE TELEVISAO.
	;Outro motivo para a distorcao eh que fui obrigado a inserir codigos
	;extras no meio dos sincronismos (que não estavam previstos qnd comecei), 
	;mas esses codigos soh sao executados na primeira linha (bits) lida da memória.
	movlw		B'00000000'	
	movwf		END_INIC_VIDEO + .0
	movwf		END_INIC_VIDEO + .1
	movwf		END_INIC_VIDEO + .2
	movwf		END_INIC_VIDEO + .3
	movwf		END_INIC_VIDEO + .4
	movwf		END_INIC_VIDEO + .5
	;6 bytes (nao devem ser modificados)


	LINE=0x06
	;linha 1/5
	movlw		B'11111111'	
	movwf		END_INIC_VIDEO + LINE + .0
	movlw		B'11111111'	
	movwf		END_INIC_VIDEO + LINE + .1
	movlw		B'11111111'		
	movwf		END_INIC_VIDEO + LINE + .2
	movlw		B'11111111'
	movwf		END_INIC_VIDEO + LINE + .3
	movlw		B'11111111'
	movwf		END_INIC_VIDEO + LINE + .4
	movlw		B'00011111'
	movwf		END_INIC_VIDEO + LINE + .5
	;linha 2/5
	movlw		B'00000001'
	movwf		END_INIC_VIDEO + LINE + .6
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINE + .7
	movlw		B'00000000'		
	movwf		END_INIC_VIDEO + LINE + .8
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINE + .9
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINE + .10
	movlw		B'00010000'
	movwf		END_INIC_VIDEO + LINE + .11

	;linha 3/5
	movlw		B'00000001'
	movwf		END_INIC_VIDEO + LINE + .12
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINE + .13
	movlw		B'00000000'		
	movwf		END_INIC_VIDEO + LINE + .14
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINE + .15
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINE + .16
	movlw		B'00010000'
	movwf		END_INIC_VIDEO + LINE + .17

	;linha 4/5
	movlw		B'10111001'
	movwf		END_INIC_VIDEO + LINE + .18
	movlw		B'00101011'
	movwf		END_INIC_VIDEO + LINE + .19
	movlw		B'00000000'		
	movwf		END_INIC_VIDEO + LINE + .20
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINE + .21
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINE + .22
	movlw		B'00010000'
	movwf		END_INIC_VIDEO + LINE + .23

	;linha 5/5
	movlw		B'10010001'
	movwf		END_INIC_VIDEO + LINE + .24
	movlw		B'10101000'
	movwf		END_INIC_VIDEO + LINE + .25
	movlw		B'01101010'		
	movwf		END_INIC_VIDEO + LINE + .26
	movlw		B'10000000'
	movwf		END_INIC_VIDEO + LINE + .27
	movlw		B'00010010'
	movwf		END_INIC_VIDEO + LINE + .28
	movlw		B'00010111'
	movwf		END_INIC_VIDEO + LINE + .29
	;30 bytes

	;TUDO ZERO
	movlw		B'10010001'
	movwf		END_INIC_VIDEO + LINE + .30
	movlw		B'10010001'
	movwf		END_INIC_VIDEO + LINE + .31
	movlw		B'10100010'	
	movwf		END_INIC_VIDEO + LINE + .32
	movlw		B'10000000'
	movwf		END_INIC_VIDEO + LINE + .33
	movlw		B'00011010'
	movwf		END_INIC_VIDEO + LINE + .34
	movlw		B'00010101'
	movwf		END_INIC_VIDEO + LINE + .35
	;6 bytes (nao devem ser modificados)


	;
	;LINHA 2
	;
	LINE=LINE+0x1E+0x06
	;linha 1/5
	movlw		B'10010001'	
	movwf		END_INIC_VIDEO + LINE + .0
	movlw		B'10101000'	
	movwf		END_INIC_VIDEO + LINE + .1
	movlw		B'10101010'		
	movwf		END_INIC_VIDEO + LINE + .2
	movlw		B'10000000'
	movwf		END_INIC_VIDEO + LINE + .3
	movlw		B'00010010'
	movwf		END_INIC_VIDEO + LINE + .4
	movlw		B'00010101'
	movwf		END_INIC_VIDEO + LINE + .5
	;linha 2/5
	movlw		B'10010001'	
	movwf		END_INIC_VIDEO + LINE + .6
	movlw		B'00101011'	
	movwf		END_INIC_VIDEO + LINE + .7
	movlw		B'01101001'		
	movwf		END_INIC_VIDEO + LINE + .8
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINE + .9
	movlw		B'01010001'
	movwf		END_INIC_VIDEO + LINE + .10
	movlw		B'00010111'
	movwf		END_INIC_VIDEO + LINE + .11
	;linha 3/5
	movlw		B'00000001'	
	movwf		END_INIC_VIDEO + LINE + .12
	movlw		B'00000000'	
	movwf		END_INIC_VIDEO + LINE + .13
	movlw		B'00000000'		
	movwf		END_INIC_VIDEO + LINE + .14
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINE + .15
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINE + .16
	movlw		B'00010000'
	movwf		END_INIC_VIDEO + LINE + .17

	;linha 4/5
	movlw		B'00000001'	
	movwf		END_INIC_VIDEO + LINE + .18
	movlw		B'00000000'	
	movwf		END_INIC_VIDEO + LINE + .19
	movlw		B'00000000'		
	movwf		END_INIC_VIDEO + LINE + .20
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINE + .21
	movlw		B'00000000'
	movwf		END_INIC_VIDEO + LINE + .22
	movlw		B'00010000'
	movwf		END_INIC_VIDEO + LINE + .23

	;linha 5/5
	movlw		B'11111111'	
	movwf		END_INIC_VIDEO + LINE + .24
	movlw		B'11111111'	
	movwf		END_INIC_VIDEO + LINE + .25
	movlw		B'11111111'		
	movwf		END_INIC_VIDEO + LINE + .26
	movlw		B'11111111'	
	movwf		END_INIC_VIDEO + LINE + .27
	movlw		B'11111111'	
	movwf		END_INIC_VIDEO + LINE + .28
	movlw		B'00011111'	
	movwf		END_INIC_VIDEO + LINE + .29
	;30 bytes

	;Memoria total consumida: 6 + 30 + 6 + 30 = 72 bytes
	;Considerando os 6 bytes usados pela funcao SAIDABIT, ficam 78 bytes.

	return


;##############################################################################
; EXECUTA OS COMANDOS RECEBIDOS PELA SERIAL E QUE FORAM ARMAZENADOS NO BUFFER
;##############################################################################
;
;O buffer de comandos (0xA0...0xAB) poderá ter uma das seguintes possibilidades:
;(vou utilizar os caracteres ( ) para separar os bytes - ou ASCII)
;                1  2345...12
;Primeiro caso: (1)(onze caracteres quaisquer) ->coloca os caracteres na linha de texto 1.
;Segundo caso : (2)(onze caracteres quaisquer) ->coloca os caracteres na linha de texto 2.
;Terceiro caso: ($)(qualquer coisa) ->entra no modo demonstração com splashwindow.
;Quarto caso  : (&)(byte indicando o numero da linha gráfica-0x00 até 0x0B)(6bytes,mas só 45bits) ->modo gráfico.
;Quinto caso  : (R)(qualquer coisa) ->inicializa o sistema.
EXECUTA_COMANDOS
;########### APÓS EXECUTAR OS COMANDOS NÃO POSSO ESQUECER DE VOLTAR PRO SEM_SINC_H!!!!!

	btfss		EXECUTA				;Testa se devo executar os comandos.
	goto		SEM_SINC_H			;Caso não precise executar nada, segue adiante.

	bcf			INTCON, PEIE		;Desabilita as interrupções dos periféricos.
	bcf			INTCON,T0IE			;Desabilita a interrupção do TMR0
									;Essas interrupções devem ser habilitadas no final.

	clrf		CONT_BUFFER2		;Limpa o contador usado no índice das letras na linha.
	bcf			MEIOBYTE 			;Limpa o MEIOBYTE para iniciar sempre no LSB.

	movlw		END_INIC_CMDS		;Carrega o endereço do primeiro caractere do buffer de comandos
	movwf		FSR					;no FSR para poder utilizar diretamente o INDF.

	movfw		INDF				;Carrego o primeiro caractere do buffer no W.
	


	;Teste para verificar qual o primeiro caractere
	bcf			STATUS,2			;Limpa o Z.
	xorlw		UM					;Codigo ASCII para o '1'.
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		ESCREVE_NA_L1		;Se o Z foi para 1, vou escrever na linha 1.
	xorlw		UM					;Restaura o W.


	;Teste para verificar qual o primeiro caractere
	bcf			STATUS,2			;Limpa o Z.
	xorlw		DO					;Codigo ASCII para o '2'.
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		ESCREVE_NA_L2		;Se o Z foi para 1, vou escrever na linha 2.
	xorlw		DO					;Restaura o W.
	
	;Teste para verificar qual o primeiro caractere
	bcf			STATUS,2			;Limpa o Z.
	xorlw		DOLAR				;Codigo ASCII para o '$'.
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		DEMONSTRACAO		;Se o Z foi para 1, Modo Demonstração.
	xorlw		DOLAR				;Restaura o W.

	;Teste para verificar qual o primeiro caractere
	bcf			STATUS,2			;Limpa o Z.
	xorlw		ECOMER				;Codigo ASCII para o '&'.
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		MODOGRAFICO			;Se o Z foi para 1, Modo Gráfico.
	xorlw		ECOMER				;Restaura o W.

	;Teste para verificar qual o primeiro caractere
	bcf			STATUS,2			;Limpa o Z.
	xorlw		RR					;Codigo ASCII para o 'R'.
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		0x00				;Se o Z foi para 1, Reinicializa o Sistema.
;	call		MSG_ERROR			;Mostra na tela uma msg de erro.
	goto 		FIM_EXECUTA_COMANDOS
	

DEMONSTRACAO
	call		SPLASHWINDOW		;Mostra na tela a SplashWindow
	goto		FIM_EXECUTA_COMANDOS

MODOGRAFICO	;Ainda não implementado
	goto		FIM_EXECUTA_COMANDOS	

ESCREVE_NA_L1
;O endereço inicial da primeira linha é: 
;  END_INIC_VIDEO + 0x06 (pula linha em branco inicial)
	movlw	END_INIC_VIDEO+0x06
	movwf	ENDERECO_INICIAL		;Carrega o endereço inicial conforme a linha.
	goto	ESCREVE_NA_LINHA

ESCREVE_NA_L2
;O endereço inicial da segunda linha é:	
;  END_INIC_VIDEO + 0x06 (linha em branco inicial) + 0x1E (1a linha) + 0x06 (linha em branco entre 1e2)
	movlw	END_INIC_VIDEO+0x06+0x1E+0x06
	movwf	ENDERECO_INICIAL		;Carrega o endereço inicial conforme a linha.
	goto	ESCREVE_NA_LINHA

FIM_EXECUTA_COMANDOS
	bcf			EXECUTA				;Desabilita a execução (só vai executar 
									;novamente se receber novo comando pela serial).

	bcf    		PIR1,RCIF    		;Limpa o RCIF Interrupt Flag.
	clrf		RCREG				;Limpa o RCREG para poder receber o prox byte e não correr risco de erro.
	bsf			INTCON, PEIE		;Habilita as interrupções dos periféricos.

	movwf		TMR0				;Recarrega o TMR0
	bcf			INTCON,T0IF			;Limpa o bit que foi setado pelo estouro do TMR0
	bsf			INTCON,T0IE			;Habilita a interrupção do TMR0

	goto		SEM_SINC_H			;Segue adiante.


ESCREVE_NA_LINHA
	incf		FSR,F				;Incrementa o ponteiro de endereços para apontar pro próximo
									;caractere do buffer de comandos.
	
	;Testa se já ultrapassou o último endereço do buffer de comandos.
	movfw		FSR						;Carrega o último endereço calculado.
	bcf			STATUS,2				;Limpa o Z.
	xorlw		END_FIM_CMDS+0x01		;Testa se é igual ao último endereço do buffer + 1.
	btfsc		STATUS,2				;Testa se o Z mudou para 1.
	goto 		FIM_EXECUTA_COMANDOS	;Se o Z foi para 1, acabou.
										;Se o Z nao foi para 1, continua executando comandos.

	movfw		ENDERECO_INICIAL		;Endereço inicial da linha na memória de vídeo.
	addwf		CONT_BUFFER2,W			;O W agora está com ENDERECO_INICIAL + ORDEM NO BUFFER.
	movwf		ENDERECO_LETRA			;Endereço inicial na memória de vídeo da letra atual.

	movfw		INDF					;Carrega o valor ASCII do caractere no W.		
	call		TABELA_ASCII
	
	btfsc		MEIOBYTE				;Faz com que eu grave um caractere a cada meio byte.
	incf		CONT_BUFFER2,F			;Garante que no primeiro caractere CONT_BUFFER2=0.
	btfsc		MEIOBYTE				;Mantém o flag alternando a cada caractere e com
	goto		LIMPA_MEIOBYTE			;isso o CONT_BUFFER2 só é incrementado com a metade
	bsf			MEIOBYTE				;da freq que os caracteres do buffer são lidos.
										;O EndereçoDaLetra também fica com metade da freq.
	goto 		ESCREVE_NA_LINHA		;Continua escrevendo até acabar o buffer de comandos.

LIMPA_MEIOBYTE
	bcf			MEIOBYTE
	goto 		ESCREVE_NA_LINHA		;Continua escrevendo até acabar o buffer de comandos.

TABELA_ASCII
	BANK1 ;Troca para o banco1 para facilitar o manuseio dos endereços neste banco.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		AA					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_A				
	xorlw		AA					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		BB					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_B				
	xorlw		BB					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		CC					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_C				
	xorlw		CC					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		DD					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_D				
	xorlw		DD					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		EE					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_E				
	xorlw		EE					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		FF					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_F				
	xorlw		FF					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		GG					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_G				
	xorlw		GG					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		HH					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_H				
	xorlw		HH					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		II					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_I				
	xorlw		II					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		JJ					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_J				
	xorlw		JJ					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		KK					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_K				
	xorlw		KK					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		LL					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_L				
	xorlw		LL					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		MM					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_M				
	xorlw		MM					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		NN					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_N				
	xorlw		NN					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		OO					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_O				
	xorlw		OO					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		PP					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_P				
	xorlw		PP					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		QQ					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_Q				
	xorlw		QQ					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		RR					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_R				
	xorlw		RR					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		SS					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_S				
	xorlw		SS					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		TT					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_T				
	xorlw		TT					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		UU					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_U				
	xorlw		UU					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		VV					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_V				
	xorlw		VV					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		WW					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_W				
	xorlw		WW					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		XX					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_X				
	xorlw		XX					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		YY					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_Y				
	xorlw		YY					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		ZZ					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		LETRA_Z				
	xorlw		ZZ					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		SP					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		ESPACO				
	xorlw		SP					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		SE					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		EXCLAMACAO				
	xorlw		SE					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		AS					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		ASPAS				
	xorlw		AS					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		SU					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		SUSTENIDO				
	xorlw		SU					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		PO					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		PORCENTO				
	xorlw		PO					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		AP					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		ABRE_PARENT				
	xorlw		AP					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		FP					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		FECHA_PARENT				
	xorlw		FP					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		MU					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		ASTERISCO				
	xorlw		MU					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		MA					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		MAIS				
	xorlw		MA					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		ME					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		MENOS				
	xorlw		ME					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		PT					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		PONTO				
	xorlw		PT					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		ZR					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		ZERO				
	xorlw		ZR					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		UM					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		UMM				
	xorlw		UM					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		DO					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		DOIS				
	xorlw		DO					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		TR					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		TRES				
	xorlw		TR					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		QU					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		QUATRO				
	xorlw		QU					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		CI					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		CINCO				
	xorlw		CI					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		SZ					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		SEIS				
	xorlw		SZ					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		ST					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		SETE				
	xorlw		ST					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		OI					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		OITO				
	xorlw		OI					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		NO					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		NOVE				
	xorlw		NO					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		DP					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		DOISPONTOS				
	xorlw		DP					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		IG					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		IGUAL				
	xorlw		IG					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		SI					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		INTERROGACAO				
	xorlw		SI					;Restaura o W.

	bcf			STATUS,2			;Limpa o Z.
	xorlw		DV					
	btfsc		STATUS,2			;Testa se o Z mudou para 1.
	goto		BARRA				
	xorlw		DV					;Restaura o W.

	goto		CHARERRO			;Não bateu com nenhum outro.



VOLTA_TABELA_ASCII
	BANK0	;Retorna para o Banco 0

	return

;Atenção: as letras são desenhadas espelhadas porque
;a rotina de leitura da memória / escrita na tela lê
;os bits do menos significativos pro mais significativos.

LETRA_A			;(0x41)
	movlw	B'00000010'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000101'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_B		 	;(0x42)
	movlw	B'00000011'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000011'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000011'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_C		 	;(0x43)
	movlw	B'00000110'
	movwf	LETRA1
	movlw	B'00000001'
	movwf	LETRA2
	movlw	B'00000001'
	movwf	LETRA3
	movlw	B'00000001'	
	movwf	LETRA4
	movlw	B'00000110'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_D		 	;(0x44)
	movlw	B'00000011'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000101'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000011'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_E		 	;(0x45)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000001'
	movwf	LETRA2
	movlw	B'00000011'
	movwf	LETRA3
	movlw	B'00000001'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_F		 	;(0x46)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000001'
	movwf	LETRA2
	movlw	B'00000011'
	movwf	LETRA3
	movlw	B'00000001'	
	movwf	LETRA4
	movlw	B'00000001'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_G		 	;(0x47)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000001'
	movwf	LETRA2
	movlw	B'00000101'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_H		 	;(0x48)
	movlw	B'00000101'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000101'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_I		 	;(0x49)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000010'
	movwf	LETRA2
	movlw	B'00000010'
	movwf	LETRA3
	movlw	B'00000010'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_J		 	;(0x4A)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000001'
	movwf	LETRA2
	movlw	B'00000001'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_K		 	;(0x4B)
	movlw	B'00000101'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000011'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000101'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_L		 	;(0x4C)
	movlw	B'00000001'
	movwf	LETRA1
	movlw	B'00000001'
	movwf	LETRA2
	movlw	B'00000001'
	movwf	LETRA3
	movlw	B'00000001'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_M		 	;(0x4D)
	movlw	B'00000101'
	movwf	LETRA1
	movlw	B'00000111'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000101'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_N		 	;(0x4E)
	movlw	B'00000011'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000101'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000101'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_O		 	;(0x4F)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000101'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_P		 	;(0x50)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000001'	
	movwf	LETRA4
	movlw	B'00000001'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_Q		 	;(0x51)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000101'
	movwf	LETRA3
	movlw	B'00000111'	
	movwf	LETRA4
	movlw	B'00000011'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_R		 	;(0x52)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000011'	
	movwf	LETRA4
	movlw	B'00000101'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_S		 	;(0x53)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000001'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000100'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_T		 	;(0x54)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000010'
	movwf	LETRA2
	movlw	B'00000010'
	movwf	LETRA3
	movlw	B'00000010'	
	movwf	LETRA4
	movlw	B'00000010'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_U		 	;(0x55)
	movlw	B'00000101'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000101'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_V		 	;(0x56)
	movlw	B'00000101'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000101'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000010'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_W		 	;(0x57)
	movlw	B'00000101'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000111'	
	movwf	LETRA4
	movlw	B'00000101'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_X		 	;(0x58)
	movlw	B'00000101'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000010'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000101'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_Y		 	;(0x59)
	movlw	B'00000101'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000010'
	movwf	LETRA3
	movlw	B'00000010'	
	movwf	LETRA4
	movlw	B'00000010'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

LETRA_Z		 	;(0x5A)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000100'
	movwf	LETRA2
	movlw	B'00000010'
	movwf	LETRA3
	movlw	B'00000001'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

ESPACO   		;(0x20)
	movlw	B'00000000'
	movwf	LETRA1
	movlw	B'00000000'
	movwf	LETRA2
	movlw	B'00000000'
	movwf	LETRA3
	movlw	B'00000000'	
	movwf	LETRA4
	movlw	B'00000000'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

EXCLAMACAO  	;(0x21)
	movlw	B'00000010'
	movwf	LETRA1
	movlw	B'00000010'
	movwf	LETRA2
	movlw	B'00000010'
	movwf	LETRA3
	movlw	B'00000000'	
	movwf	LETRA4
	movlw	B'00000010'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

ASPAS		  	;(0x22)
	movlw	B'00000101'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000000'
	movwf	LETRA3
	movlw	B'00000000'	
	movwf	LETRA4
	movlw	B'00000000'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

SUSTENIDO	  	;(0x23)
	movlw	B'00000101'
	movwf	LETRA1
	movlw	B'00000111'
	movwf	LETRA2
	movlw	B'00000101'
	movwf	LETRA3
	movlw	B'00000111'	
	movwf	LETRA4
	movlw	B'00000101'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

PORCENTO	  	;(0x25)
	movlw	B'00000101'
	movwf	LETRA1
	movlw	B'00000100'
	movwf	LETRA2
	movlw	B'00000010'
	movwf	LETRA3
	movlw	B'00000001'	
	movwf	LETRA4
	movlw	B'00000101'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

ABRE_PARENT  	;(0x28)	
	movlw	B'00000010'
	movwf	LETRA1
	movlw	B'00000001'
	movwf	LETRA2
	movlw	B'00000001'
	movwf	LETRA3
	movlw	B'00000001'	
	movwf	LETRA4
	movlw	B'00000010'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

FECHA_PARENT  	;(0x29)	

	movlw	B'00000010'
	movwf	LETRA1
	movlw	B'00000100'
	movwf	LETRA2
	movlw	B'00000100'
	movwf	LETRA3
	movlw	B'00000100'	
	movwf	LETRA4
	movlw	B'00000010'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

ASTERISCO	  	;(0x2A)	
	movlw	B'00000000'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000010'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000000'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

MAIS		  	;(0x2B)	
	movlw	B'00000010'
	movwf	LETRA1
	movlw	B'00000010'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000010'	
	movwf	LETRA4
	movlw	B'00000010'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

MENOS		  	;(0x2D)	
	movlw	B'00000000'
	movwf	LETRA1
	movlw	B'0000000'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000000'	
	movwf	LETRA4
	movlw	B'00000000'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

PONTO		  	;(0x2E)	
	movlw	B'00000000'
	movwf	LETRA1
	movlw	B'00000000'
	movwf	LETRA2
	movlw	B'00000000'
	movwf	LETRA3
	movlw	B'00000000'	
	movwf	LETRA4
	movlw	B'00000010'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

ZERO		  	;(0x30)		
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000101'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

UMM			  	;(0x31)		
	movlw	B'00000100'
	movwf	LETRA1
	movlw	B'00000110'
	movwf	LETRA2
	movlw	B'00000101'
	movwf	LETRA3
	movlw	B'00000100'	
	movwf	LETRA4
	movlw	B'00000100'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

DOIS		  	;(0x32)		
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000100'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000001'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

TRES		  	;(0x33)		
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000100'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000100'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

QUATRO		  	;(0x34)
	movlw	B'00000101'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000100'	
	movwf	LETRA4
	movlw	B'00000100'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

CINCO		  	;(0x35)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000001'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000100'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

SEIS 		 	;(0x36)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000001'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

SETE 		 	;(0x37)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000100'
	movwf	LETRA2
	movlw	B'00000010'
	movwf	LETRA3
	movlw	B'00000010'	
	movwf	LETRA4
	movlw	B'00000010'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

OITO 		 	;(0x38)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000101'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

NOVE 		 	;(0x39)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000101'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000100'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

DOISPONTOS	 	;(0x3A)
	movlw	B'00000000'
	movwf	LETRA1
	movlw	B'00000010'
	movwf	LETRA2
	movlw	B'00000000'
	movwf	LETRA3
	movlw	B'00000010'	
	movwf	LETRA4
	movlw	B'00000000'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

IGUAL		 	;(0x3D)
	movlw	B'00000000'
	movwf	LETRA1
	movlw	B'00000111'
	movwf	LETRA2
	movlw	B'00000000'
	movwf	LETRA3
	movlw	B'00000111'	
	movwf	LETRA4
	movlw	B'00000000'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

INTERROGACAO 	;(0x3F)
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000100'
	movwf	LETRA2
	movlw	B'00000010'
	movwf	LETRA3
	movlw	B'00000000'	
	movwf	LETRA4
	movlw	B'00000010'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

BARRA
	movlw	B'00000100'
	movwf	LETRA1
	movlw	B'00000010'
	movwf	LETRA2
	movlw	B'00000010'
	movwf	LETRA3
	movlw	B'00000010'	
	movwf	LETRA4
	movlw	B'00000001'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII

	goto	VOLTA_TABELA_ASCII

CHARERRO
	movlw	B'00000111'
	movwf	LETRA1
	movlw	B'00000111'
	movwf	LETRA2
	movlw	B'00000111'
	movwf	LETRA3
	movlw	B'00000111'	
	movwf	LETRA4
	movlw	B'00000111'
	movwf	LETRA5
	call	PASSA_LETRA_MEMORIA
	goto	VOLTA_TABELA_ASCII


MASCARA_LSB
	retlw	B'11110000'			;Máscara para zerar os LSBs do W.

MASCARA_MSB
	retlw	B'00001111'			;Máscara para zerar os MSBs do W.


PASSA_LETRA_MEMORIA
	movfw	FSR
	movwf	SALVA_FSR2			;Salva o FSR.

	movfw	ENDERECO_LETRA		;Carrega o endereço inicial da letra no FSR.
	movwf	FSR

	btfss	MEIOBYTE
	call	MASCARA_LSB	
	btfsc	MEIOBYTE
	call	MASCARA_MSB
	andwf	INDF,F				;Passa o primeiro byte pela máscara

	btfsc	MEIOBYTE
	swapf	LETRA1,W			;Se for o MSB, troca os nibbles e guarda em W.
	btfss	MEIOBYTE
	movfw	LETRA1
	iorwf	INDF,F				;Agora armazena o novo caractere.

	movfw	FSR
	addlw	0x06				;Realiza o pulo pra próxima linha de pixels
	movwf	FSR

	btfss	MEIOBYTE
	call	MASCARA_LSB	
	btfsc	MEIOBYTE
	call	MASCARA_MSB
	andwf	INDF,F				;Passa o primeiro byte pela máscara

	btfsc	MEIOBYTE
	swapf	LETRA2,W			;Se for o MSB, troca os nibbles e guarda em W.
	btfss	MEIOBYTE
	movfw	LETRA2
	iorwf	INDF,F				;Agora armazena o novo caractere.

	movfw	FSR
	addlw	0x06				;Realiza o pulo pra próxima linha de pixels
	movwf	FSR

	btfss	MEIOBYTE
	call	MASCARA_LSB	
	btfsc	MEIOBYTE
	call	MASCARA_MSB
	andwf	INDF,F				;Passa o primeiro byte pela máscara

	btfsc	MEIOBYTE
	swapf	LETRA3,W			;Se for o MSB, troca os nibbles e guarda em W.
	btfss	MEIOBYTE
	movfw	LETRA3
	iorwf	INDF,F				;Agora armazena o novo caractere.

	movfw	FSR
	addlw	0x06				;Realiza o pulo pra próxima linha de pixels
	movwf	FSR

	btfss	MEIOBYTE
	call	MASCARA_LSB	
	btfsc	MEIOBYTE
	call	MASCARA_MSB
	andwf	INDF,F				;Passa o primeiro byte pela máscara

	btfsc	MEIOBYTE
	swapf	LETRA4,W			;Se for o MSB, troca os nibbles e guarda em W.
	btfss	MEIOBYTE
	movfw	LETRA4
	iorwf	INDF,F				;Agora armazena o novo caractere.

	movfw	FSR
	addlw	0x06				;Realiza o pulo pra próxima linha de pixels
	movwf	FSR

	btfss	MEIOBYTE
	call	MASCARA_LSB	
	btfsc	MEIOBYTE
	call	MASCARA_MSB
	andwf	INDF,F				;Passa o primeiro byte pela máscara

	btfsc	MEIOBYTE
	swapf	LETRA5,W			;Se for o MSB, troca os nibbles e guarda em W.
	btfss	MEIOBYTE
	movfw	LETRA5
	iorwf	INDF,F				;Agora armazena o novo caractere.


	movfw	SALVA_FSR2			;Restaura o FSR.
	movwf	FSR
	
	return


;****************************************************************************
;*							FIM DO PROGRAMA									*
;****************************************************************************


	END							;INDICA O FIM DO ARQUIVO CÓDIGO-FONTE
	

;Modelo de estruturação de códido baseado no exemplo do livro "Desbravando o PIC-Editora Érica"
