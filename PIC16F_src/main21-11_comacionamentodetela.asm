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
;* -Criar arquivos para as MACROS gen�ricas e espec�ficas a este programa   *
;* depois � s� usar um #INCLUDE <MINHASMACROS.MAC>																			*
;****************************************************************************

;****************************************************************************
;*							ARQUIVOS DE DEFINI��ES							*
;****************************************************************************

#INCLUDE <P16F628A.inc>       ; processor specific variable definitions
;Estou usando o 628 e nao o 628A para testar no mcflash.
;Na versao final, devera ser usado o P16F628A.inc

	errorlevel 1,-207
	;Desabilita uma warning chata.

;
	__CONFIG   _CP_OFF & _DATA_CP_OFF & _LVP_OFF & _BOREN_ON & _MCLRE_OFF & _WDT_OFF & _PWRTE_ON & _HS_OSC;_INTOSC_OSC_NOCLKOUT
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

	CBLOCK		0x20				;ENDERE�O INICIAL DA MEM�RIA DE USU�RIO
				W_TEMP				;REGISTRADORES TEMPOR�RIOS PARA USO (0x20)
				STATUS_TEMP			;JUNTO �S INTERRUP��ES (0x21)
				;AQUI IR�O AS NOVAS VARI�VEIS
				DELAY				;Uso geral (0x22)
				CONTADORLED_OERR	;Contador usado para manter o led aceso por algum tempo (0x23)
				CONT_VERT			;Usada para contar o numero de linhas horizontais que foram desenhadas (0x24)
				FLAGS				;Usado para as flags do programa (0x25)

	ENDC						;FIM DO BLOCO DE MEM�RIA

;CBLOCK e ENDC: � uma maneira simplificada de definirmos v�rios EQUs com 
;endere�os sequenciais. Assim fica mais f�cil a migra��o para outro processador ou
;para outro bloco de endere�os.



;****************************************************************************
;*							FLAGS INTERNOS									*
;****************************************************************************
;DEFINI��O DE TODOS OS FLAGS UTILIZADOS PELO SISTEMA

#DEFINE			SINC_H	FLAGS,0			;Usado para sinalizar que iniciou uma linha
										;horizontal (apos o sincronismo)

#DEFINE			SINC_V	FLAGS,1			;Sinaliza quando fazer o sincronismo

#DEFINE			ODD		FLAGS,2			;Sinaliza se o campo eh par ou impar
										;ODD->1 impar
										;ODD->0 par

#DEFINE			TELA	FLAGS,3			;Libera ou nao o desenho na tela
										;TELA->1 libera
										;TELA->0 nivel de preto

;****************************************************************************
;*								CONSTANTES									*
;****************************************************************************
;DEFINI��O DE TODAS AS CONSTANTES UTILIZADAS PELO SISTEMA

INIC_TMR0 		EQU		.102			;Inicializa o TMR0 para
										;poder colocar um nivel de
										;preto no final da imagem e
										;garantir o sincronismo correto

;****************************************************************************
;*								MACROS     									*
;****************************************************************************

;Esta macro foi necess�ria para facilitar a manuten��o do c�digo fonte.
;Sem uma macro, esse conjunto de instru��es seria repetido para cada bit lido
;tornando o arquivo fonte ileg�vel para o programador.
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
; IMPORTANTE: quando essa macro for chamada, o W deve conter o valor .2 (decimal)!!!!
SAIDABIT	MACRO	ENDERECO_INI, ENDERECO_FIN, NBIT, ROTULO
				VARIABLE	i=0						;define uma vari�vel para o compilador
													;N�O ESTAR� PRESENTE NO ASSEMBLY!
				VARIABLE	it=0					;usada para medir o total de bits
				VARIABLE	ENDERECO=ENDERECO_INI

				WHILE (ENDERECO<=ENDERECO_FIN & it<NBIT)
				WHILE (i<8)
					btfss		ENDERECO,i
					GOTO		ROTULO+(6*(it+1))-2
					;SETA PINO
					bsf			saida				;Seta o pino de sa�da pra 1
					goto		ROTULO+(6*(it+1))	;"M�gica" usada para pular para as linhas corretas 
													;ROTULO_INICIAL + NUMERO_DE_INSTRUCOES_DA_MACRO*BITS_LIDOS
					;LIMPA PINO
					bcf			saida				;Seta o pino de sa�da pra 0
					nop
				i+=1
				it+=1

				IF it==NBIT							;Este IF eh encarregado de parar no bit correto
					EXITM	;Nao sei o porque, mas soh funciona nos 8 primeiros bits?!?! 						
				ENDIF

				ENDW ;fim do 2� while
				i=0
				ENDERECO+=1
				ENDW ;fim do 1� while
			ENDM

;NOPS 
;Gera um delay de TEMPO ciclos
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


;****************************************************************************
;*									SA�DAS									*
;****************************************************************************
;DEFINI��O DE TODOS OS PINOS QUE SER�O UTILIZADOS COMO SA�DA
;RECOMENDAMOS TAMB�M COMENTAR O SIGNIFICADO DE SEUS ESTADOS (0 E 1)

#DEFINE			saida		PORTB,5		;A princ�pio, esta ser� a sa�da de v�deo
										;- 1 para branco
										;- 0 para preto

#DEFINE			sincronismo PORTB,3		;Usado para gerar o sincronismo em conj
										;com o pino saida
										;saida-0 e sincronismo-0: sinal de sincronismo (0V)
										;saida-0 e sincronismo-1: nivel de preto
										;saida-1 e sincronismo-1: nivel de branco

#DEFINE			LED_OERR	PORTA,1		;Define o pino do led que indicar� o erro no recebimento
										;da serial.										
										;- 1 apagado (normal)
										;- 0 aceso (erro overrun no recebimento)

#DEFINE			LED_SEROK	PORTB,4		;DEBUG APENAS
#DEFINE			LED_SERERR	PORTB,6		;DEBUG APENAS

;****************************************************************************
;*								VETOR DE RESET								*
;****************************************************************************
	ORG 		0x00				;ENDERE�O INICIAL DE PROCESSAMENTO
	GOTO 		INICIO



;****************************************************************************
;*						IN�CIO DAS INTERRUP��ES								*
;****************************************************************************
;ENDERE�OS DE DESVIO DAS INTERRUP��ES, A PRIMEIRA TAREFA � SALVAR OS VALORES
;DE "W" E "STATUS" PARA RECUPERA��O FUTURA

	ORG 		0x04				;ENDERE�O INICIAL DAS INTERRUP��ES
	MOVWF		W_TEMP				;COPIA W PARA W_TEMP
	SWAPF 		STATUS,0
	MOVWF		STATUS_TEMP			;COPIA STATUS PARA STATUS_TEMP


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

	goto		SAI_INT

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

	;Neste ponto, termina a borda preta do inicio do pulso horizontal
	;e comeca o pulso de sincronismo.
	bcf			sincronismo
	;Inicio do pulso de 4.8uS no nivel de sincronismo
	;24 ciclos.
	;NOPS .24
	;Codigo usado para ligar ou desligar linhas na imagem
	movlw		.100
	bcf			STATUS,1			;Limpa o Borrow
	subwf		CONT_VERT,W
	btfsc		STATUS,1
	goto		DESENHA_TELA
	goto		NAO_DESENHA_TELA
DESENHA_TELA
	bsf			TELA				;Ativa a saida de imagem	
	goto		FIM_DESENHA_TELA
NAO_DESENHA_TELA
	bcf			TELA				;Desativa a saida de imagem
	nop								;Para manter o mesmo numero de ciclos
FIM_DESENHA_TELA
	;9 ciclos que devem ser retirados do NOPS .24
	NOPS .15	
	;fim do pulso de 4.8uS (24 ciclos@20MHz)

	bsf			sincronismo
	;Inicio do pulso de 4.8uS no nivel de preto (24 ciclos@20MHz)
	;Aqui eu utilizaria 24 ciclos, mas como sao gastos 8 ciclos para
	;sair da interrupcao do timer0 diminuo aqui.
	;24 - 9 = 15 ciclos - 2 = 13
	NOPS .15

	incfsz		CONT_VERT,f			;Conta ateh 242 e depois sinaliza
	goto		SEM_SINCV_AINDA
	bsf			SINC_V				;que eh hora da sincronia vertical

SEM_SINCV_AINDA
	;nop
	bsf			SINC_H					;Ativa a saida de imagem
	;Comentei a linha acima para coloca-la dentro de um periodo de nops de
	;um dos pulsos gerados logo acima. Tive de colocar um nop para manter temporizacao.

	goto		SAI_INT ;2 ciclos

;
;Tratamento da interrup��o devido � recep��o pela Serial
INT_SERIAL
	bcf    		PIR1,RCIF    		;Limpa o RCIF Interrupt Flag

	movf		RCREG,W				;Carregou o conteudo recebido no W
	clrf		RCREG				;Limpa o RCREG para poder receber o prox byte

	;DEBUG: teste para verificar se recebi um 'A'
	bcf			STATUS,2			;Limpa o Z
	xorlw		0x41				;Codigo ASCII para o 'A'
	btfsc		STATUS,2			;Testa se o Z mudou para 1
	goto 		LEDOK				;Se o Z foi para 1, recebi o A
	goto		LEDERR				;Caso contrario, deu erro.

LEDOK:
	bsf 		LED_SEROK
	bcf			LED_SERERR	
	goto 		CONTINUA
LEDERR
	bsf			LED_SERERR
	bcf			LED_SEROK
	goto		CONTINUA

CONTINUA:
	;FIM DO DEBUG
	btfsc		RCSTA,OERR			;Testa se houve erro na recep��o (overrun error)
	goto		ERRO_OERR
;Se n�o ocorreu o erro, devo garantir que o led estar� apagado?
;-N�o, porque o led inicia apagado e depois o controle se encarrega disso.
	goto		SAI_INT


;Tratamento do Overrun Error e acendimento / apagamento do led indicativo
ERRO_OERR
	bcf			LED_OERR			;Acende o led
;	incfsz		CONTADORLED_OERR	;Incrementa o contador e se for zero apaga o bit OERR
									;e desliga o led indicador.
;	goto		SAI_INT
	
	bcf			RCSTA,CREN			;Desliga o bit OERR (ele � ligado por hardware)
	bcf			RCSTA,CREN			;Note que para desligar o OERR � necess�rio
									;desligar e ligar o CREN (que ativa o recebimento.

	bsf			LED_OERR			;Desliga o led indicador de erro na serial

	goto 		SAI_INT

	
;Aqui eu deveria ligar o led que indicar� esse tipo de erro
;O bit OERR deve ser limpo por software. Preciso implementar um contador
;para garantir que o led ficar� tempo suficiente aceso para que um ser humano
;consiga perceb�-lo


;****************************************************************************
;*							ROTINA DE SA�DA DA INTERRUP��O					*
;****************************************************************************
;OS VALORES DE "W" E "STATUS" DEVEM SER RECUPERADOS ANTES DE RETORNAR DA INTERRUP��O

SAI_INT
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

;SUBROTINA1
	;CORPO DA ROTINA

;	RETURN


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
		

	bsf			INTCON,T0IE			;Habilita a interrup��o do TMR0
	bsf			INTCON, PEIE		;Habilita as interrup��es dos perif�ricos.
	bsf			INTCON,GIE			;Ativa as interrup��es

	BANK0
	bcf			LED_OERR			;Inicia o programa com o led limpo (apagado) para OK

;Fim do MEU SETUP


;****************************************************************************
;*							INICIALIZA��O DAS VARI�VEIS						*
;****************************************************************************

	movlw		.0
	movwf		CONTADORLED_OERR	;Inicializa o contador do LED_OERR

	movlw		.14
	movwf		CONT_VERT			;Inicializa o contador de linhas
									;para conseguir contar 242 linhas

	bcf			SINC_H				;Para que a imagem soh comece depois do
									;TIMER0 ter estourado uma primeira vez.

	bsf			ODD					;O primeiro campo eh impar
	
	bcf			SINC_V				;Nunca comeca com sincronismo vertical

	bcf			TELA				;Inicia com tela preta

;****************************************************************************
;*							CORPO DA ROTINA PRINCIPAL						*
;****************************************************************************

MAIN
	;CORPO DA ROTINA PRINCIPAL

	movlw		B'01110111'		;Carrega a mem�ria RAM com esse valor
	movwf		0x50			;para eu poder testar as rotinas de leitura/escrita de bit
	movlw		B'00000101'		;no pino definido por saida.'
	movwf		0x51	
	movlw		B'00011000'		
	movwf		0x52
	movlw		B'00000000'
	movwf		0x53
	movlw		B'00000000'
	movwf		0x54
	movlw		B'00101000'
	movwf		0x55

SEM_SINC_H
	btfss		SINC_H
	goto		SEM_SINC_H

	btfsc		SINC_V
	goto		SINCRONISMO_VERTICAL

	bcf			saida						;Garante as linhas pares apagadas

	btfss		ODD
	goto		SEM_SINC_H

	;Preciso de 7 ciclos de atraso neste ponto
	nop										;Importante para manter o sincronismo
	nop										;Tenho que procurar onde esta faltando esse tempo
	nop
	nop	
	nop
	nop
;A imagem deve estar armazenada na memoria para ser lida
;conforme eh feito abaixo (cada vez que for escrita uma linha)
	
	btfsc		TELA						;Testa se posso desenhar
											;algo na tela (reduzi um dos nops anteriores)
bit00
	SAIDABIT 0x50,0x55,46,bit00


;Fim da leitura da imagem da memoria
	bsf			saida

	bcf			SINC_H
	goto SEM_SINC_H

SINCRONISMO_VERTICAL

;PRIMEIRA EQUALIZACAO
;Sao tres linhas com seis pulsos de sincronizacao

	;Primeira linha - H1
	;P1.1
	;Pulso de sincronismo com 4.8uS=>24ciclos
	bcf			saida
	bcf			sincronismo
	NOPS		.24
	
	;P2.1
	;Pulso nivel de preto com 26.95uS=>135ciclos
	;Como esse pulso eh bem demorado, posso aproveitar pra
	;fazer alguma coisa nesse tempo livre.
	bsf			sincronismo
	bcf			INTCON,T0IE			;Desabilita a interrup��o do TMR0
									;para que ele nao estoure no meio de V_SINC
	NOPS		.134

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
	movlw		.0
	movwf		TMR0				;Recarrega o TMR0
	bcf			INTCON,T0IF			;Limpa o bit que foi setado pelo estouro do TMR0
	bsf			INTCON,T0IE			;Desabilita a interrup��o do TMR0
									;para que ele nao estoure no meio de V_SINC
	goto		SEM_SINC_H



;****************************************************************************
;*							FIM DO PROGRAMA									*
;****************************************************************************


	END							;INDICA O FIM DO ARQUIVO C�DIGO-FONTE
	

;Modelo de estrutura��o de c�dido baseado no exemplo do livro "Desbravando o PIC"
