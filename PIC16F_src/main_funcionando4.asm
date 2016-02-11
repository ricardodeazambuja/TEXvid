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
				CONTADORLED_OERR	;Contador usado para manter o led aceso por algum tempo (0x22)
				FLAGS				;Usado para as flags do programa (0x23)

	ENDC						;FIM DO BLOCO DE MEM�RIA

;CBLOCK e ENDC: � uma maneira simplificada de definirmos v�rios EQUs com 
;endere�os sequenciais. Assim fica mais f�cil a migra��o para outro processador ou
;para outro bloco de endere�os.



;****************************************************************************
;*							FLAGS INTERNOS									*
;****************************************************************************
;DEFINI��O DE TODOS OS FLAGS UTILIZADOS PELO SISTEMA



;****************************************************************************
;*								CONSTANTES									*
;****************************************************************************
;DEFINI��O DE TODAS AS CONSTANTES UTILIZADAS PELO SISTEMA

;INIC_TMR0 		EQU		.103			;Inicializa o TMR0
INIC_TMR0 		EQU		.106			;Inicializa o TMR0 para
										;poder colocar um nivel de
										;preto no final da imagem e
										;garantir o sincronismo correto

#DEFINE			SINC_H	FLAGS,0



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
;					addwf		PCL,1				;Tem o mesmo efeito do goto, mas com uma �nica instru��o	
					GOTO		ROTULO+(6*(it+1))-2
					;SETA PINO
					bsf			saida				;Seta o pino de sa�da pra 1
					goto		ROTULO+(6*(it+1))	;"M�gica" usada para pular para as linhas corretas 
													;ROTULO_INICIAL + NUMERO_DE_INSTRUCOES_DA_MACRO*BITS_LIDOS
					;LIMPA PINO
					bcf			saida				;Seta o pino de sa�da pra 0
					nop
;					nop								;Se vc n�o sabe o que isso significa...
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
;Gera um monte de... nop!
; - N    	: n�mero de nops
NOPS	MACRO	N
				VARIABLE	i=0						;define uma vari�vel para o compilador
													;N�O ESTAR� PRESENTE NO ASSEMBLY!
				WHILE i<N
					nop
				i+=1
				ENDW ;fim do primeiro while
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
	;3 ciclos ateh aqui (600nS@20MHz)

	;Inicia a borda preta do sincronismo para economizar tempo
	bcf			saida

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


;Tratamento da interrup��o por estouro do Timer0
INT_TIMER0 ;Ateh aqui foram 6 ciclos
	bcf			INTCON,T0IF			;Limpa o bit que foi setado pelo estouro do TMR0
	bsf			SINC_H				;Agora a imagem jah podera ser mostrada

	movlw		INIC_TMR0
	movwf		TMR0				;Recarrega o TMR0

	;Ateh aqui consigo 1.6uS de preto
	;Comentei as linhas abaixo, porque elas geravam esse
	;pulso de preto no inicio do sincronismo horizontal

	;Neste ponto, sera feito o sincronismo, ficando liberado
	;para reproducao de imagem apos ele ter ocorrido.
;	bcf			saida
;	bsf			sincronismo
	;Inicio da contagem do tempo
;	NOPS		7	
	;tempo aprox.=1.4uS

	bcf			sincronismo
	;Inicio do pulso de 4.7uS no nivel de sincronismo
	NOPS		24
	;fim do pulso de 4.7uS (23.5 ciclos@20MHz)

	bsf			sincronismo
	;Inicio do pulso de 4.8uS no nivel de preto (24 ciclos@20MHz)
	;Aqui eu utilizaria 24 nops, mas como sao gastos 8 ciclos para
	;sair da interrupcao do timer0 diminuo aqui
	NOPS 		16
	;fim do pulso de 4.8uS
	;AQUI INICIA A IMAGEM!!!!
	;Apos passar no RETFIE, serao gastos 93 ciclos (18.6uS)
	;sobrando, assim, somente 63.4uS-18.6uS=44.8uS para
	;desenhar algo na tela!
	;44.8uS=>224ciclos 


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
	;Este pequeno trecho consome 6 ciclos

;OBSERVA��ES: 
;- A utiliza��o de SWAPF ao inv�s de MOVF evita a altera��o do STATUS.
;- No in�cio do tratamento da interrup��o, a chave geral � desligada automaticamente
;e depois do RETFIE ela � religada.

;****************************************************************************
;*							ROTINAS E SUBROTINAS							*
;****************************************************************************
;CADA ROTINA OU SUBROTINA DEVE POSSUIR A DESCRI��O DE FUNCIONAMENTO E UM
;NOME COERENTE �S SUAS FUN��ES

SUBROTINA1
	;CORPO DA ROTINA

	RETURN


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

;Meu setup
;Aqui s�o configurados os registrados especiais (SFR) para o funcionamento correto do sistema
;Para mais informa��es sobre os bits dos SFRs, ver livro p�g 193
	BANK0
	movlw		.0
	movwf		TMR0				;Inicializa o TMR0 com ZERO
									;Para que ele nao estoure antes de fazer as configurascoes.
	;Setup para recep��o pela USART ass�ncrona.
	;A configura��o ser� feita para 2400-8N1.
	;Baud-Rate 2400, 8 bits de dados, sem paridade e um stop-bit.
	BANK1
	movlw		.129				;Carrega o valor para
	movwf		SPBRG				;setar o BaudRate da USART para 2400@20MHz.

	bcf			TXSTA, SYNC			;Habilita a Porta Serial Ass�ncrona
	bcf			TXSTA, BRGH			;Seta para Low Speed Baud
	;Ateh este pto, soh ajustei o baud-rate para 2400

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


;Fim do Meu setup

;****************************************************************************
;*							INICIALIZA��O DAS VARI�VEIS						*
;****************************************************************************

	movlw		.0
	movwf		CONTADORLED_OERR	;Inicializa o contador do LED_OERR

	bcf			SINC_H				;Para que a imagem soh comece depois do
									;TIMER0 ter estourado uma vez

;****************************************************************************
;*							CORPO DA ROTINA PRINCIPAL						*
;****************************************************************************

MAIN
	;CORPO DA ROTINA PRINCIPAL

	movlw		B'10101010'		;Carrega a mem�ria RAM com esse valor
	movwf		0x24			;para eu poder testar as rotinas de leitura/escrita de bit
	movwf		0x25			;no pino definido por saida.'
	movwf		0x26
	movwf		0x27
	movwf		0x28
	movwf		0x29
	
SEM_SINC_H
	btfss		SINC_H
	goto		SEM_SINC_H

	bsf			saida
	NOPS		3	
bit00
	SAIDABIT 0x24,0x28,40,bit00
bit01
	SAIDABIT 0x29,0x29,3,bit01

	bsf			saida
	NOPS		3

	bcf			SINC_H
	goto SEM_SINC_H

;****************************************************************************
;*							FIM DO PROGRAMA									*
;****************************************************************************


	END							;INDICA O FIM DO ARQUIVO C�DIGO-FONTE
	

;Modelo de estrutura��o de c�dido baseado no exemplo do livro "Desbravando o PIC"
