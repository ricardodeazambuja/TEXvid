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
;* -RA2 (SA�DA DO V�DEO COMPOSTO)									        *
;* -RA1 (LED INDICADOR DE ERRO NA SERIAL)
;* -Criar arquivos para as MACROS gen�ricas e espec�ficas a este programa   *
;* depois � s� usar um #INCLUDE <MINHASMACROS.MAC>																			*
;****************************************************************************

;****************************************************************************
;*							ARQUIVOS DE DEFINI��ES							*
;****************************************************************************

#INCLUDE <P16F628A.inc>       ; processor specific variable definitions



	__CONFIG   _CP_OFF & _DATA_CP_OFF & _LVP_OFF & _BODEN_ON & _MCLRE_OFF & _WDT_OFF & _PWRTE_ON & _HS_OSC
; Ver livro Desbravando o PIC p�g 62 para as configura��es

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
				W_TEMP				;REGISTRADORES TEMPOR�RIOS PARA USO
				STATUS_TEMP			;JUNTO �S INTERRUP��ES
				;AQUI IR�O AS NOVAS VARI�VEIS
				CONTADORLED_OERR	;Contador usado para manter o led aceso por algum tempo

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

INIC_TMR0 		EQU		.0			;Inicializa o TMR0



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
; - ENDERECO_FIN: endere�o final.
; - NBIT    : n�mero de bits a serem lidos no total (assim n�o preciso ler bytes inteiros)
; - ROTULO  : r�tulo inicial para servir como endere�o base na mem�ria de programa.
SAIDABIT	MACRO	ENDERECO_INI, ENDERECO_FIN, NBIT, ROTULO
				VARIABLE	i=0						;define uma vari�vel para o compilador
													;N�O ESTAR� PRESENTE NO ASSEMBLY!
				VARIABLE	ENDERECO=ENDERECO_INI
				WHILE ENDERECO<=ENDERECO_FIN
				WHILE i<NBIT
					btfss		ENDERECO,i
					addwf		PCL,1				;Tem o mesmo efeito do goto, mas com uma �nica instru��o	
					bsf			saida				;Seta o pino de sa�da pra 1
					goto		ROTULO+(7*(i+1))	;"M�gica" usada para pular para as linhas corretas 
													;usando o endere�o inicial passado para a macro na forma de r�tulo
					bcf			saida				;Seta o pino de sa�da pra 0
					nop
					nop								;Se vc n�o sabe o que isso significa...
				i+=1
				ENDW ;fim do segundo while
				i=0
				ENDERECO+=1
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

#DEFINE			saida		PORTA,2		;A princ�pio, esta ser� a sa�da de v�deo RA2
										;- 1 para branco
										;- 0 para preto
										;- alta imped�ncia para sincronismo
										;*para o sincronismo deve-se mudar no TRISA

#DEFINE			LED_OERR	PORTA,1		;Define o pino do led que indicar� o erro no recebimento
										;da serial.										
										;- 1 apagado (normal)
										;- 0 aceso (erro overrun no recebimento)


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
	SWAPF 		STATUS,W
	MOVWF		STATUS_TEMP			;COPIA STATUS PARA STATUS_TEMP
	

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
INT_TIMER0
	bcf			INTCON,T0IF			;Limpa o bit que foi setado pelo estouro do TMR0
	movlw		INIC_TMR0
	movwf		TMR0				;Recarrega o TMR0

	btfsc		PORTB,7
	goto 		LIMPAR
	goto		SETAR

LIMPAR
	bcf			PORTB,7
	bsf			PORTA,2
	goto		SAI_INT

SETAR
	bsf			PORTB,7
	bcf			PORTA,2
	goto		SAI_INT

;Tratamento da interrup��o devido � recep��o pela Serial
INT_SERIAL
	bcf    		PIR1,RCIF    		;Clear RCIF Interrupt Flag

	movlw		.0
	movf		RCREG,W

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
	SWAPF		STATUS_TEMP,W
	MOVWF		STATUS				;MOVE STATUS_TEMP PARA STATUS
	SWAPF		W_TEMP,F
	SWAPF		W_TEMP,W			;MOVE W_TEMP PARA W
	RETFIE							;RETORNA DA INTERRUP��O (VER ESQUEMA LIVRO P�G 135)

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
;Limpa a mem�ria RAM a partir do endere�o 0x20
;Trecho de c�digo retirado do datasheet PICmicro MID-RANGE MCU FAMILY

	CLRF 		STATUS 				; Clear STATUS register (Bank0)
	MOVLW 		0x20 				; 1st address (in bank) of GPR area
	MOVWF 		FSR		 			; Move it to Indirect address register
Bank0_LP
	CLRF 		INDF 				; Clear GPR at address pointed to by FSR
	INCF 		FSR, 1 				; Next GPR (RAM) address
	BTFSS 		FSR, 7 				; End of current bank ? (FSR = 80h, C = 0)
	GOTO 		Bank0_LP 			; NO, clear next location
;
; Next Bank (Bank1)
; (** ONLY REQUIRED IF DEVICE HAS A BANK1 **)
;
	MOVLW 		0xA0 				; 1st address (in bank) of GPR area
	MOVWF 		FSR 				; Move it to Indirect address register
Bank1_LP
	CLRF 		INDF 				; Clear GPR at address pointed to by FSR
	INCF 		FSR, 1 				; Next GPR (RAM) address
	NOP
	BTFSS 		STATUS, Z 			; End of current bank? (FSR = 00h, Z = 1)
	GOTO 		Bank1_LP 			; NO, clear next location

;Fim da limpeza da mem�ria
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
	MOVLW		B'00000000'
	MOVWF		INTCON				;DEFINE OP��ES DE INTERRUP��ES

;Meu setup
;Aqui s�o configurados os registrados especiais (SFR) para o funcionamento correto do sistema
;Para mais informa��es sobre os bits dos SFRs, ver livro p�g 193
	BANK0
	movlw		INIC_TMR0
	movwf		TMR0				;Inicializa o TMR0 com 0
	BANK1

	;Setup para recep��o pela USART ass�ncrona.
	;A configura��o ser� feita para 9600-8N1.
	;Baud-Rate 9600, 8 bits de dados, sem paridade e um stop-bit.
	movlw		.129				;Carrega o valor para
	movwf		SPBRG				;setar o BaudRate da USART para 9600.

	bcf			TXSTA, SYNC			;Habilita a Porta Serial Ass�ncrona
	bsf			TXSTA, BRGH			;Seta para High Speed Baud
	BANK0							;limpando o SYNC e setando o SPEN.
	bsf			RCSTA, SPEN			;
	BANK1
	bsf			PIE1, RCIE			;Habilita a interrup��o de recep��o
	BANK0
	bcf			RCSTA, RX9D			;Desabilita a recep��o de 9bits (usada para o CRC por software).
	bsf			RCSTA, CREN			;Habilita a recep��o.
	;Fim do setup da serial


	BANK1
	bcf			OPTION_REG,T0CS 	;Seta o TMR0 para o timer mode - incrementa a cada ciclo de clock
	bsf			OPTION_REG,PSA		;Ativa o Prescaler para o WDT fazendo com que o TIMER0 fique 1:1
	bsf			INTCON,T0IE			;Habilita a interrup��o do TMR0
	bsf			INTCON, PEIE		;Habilita as interrup��es dos perif�ricos.
	bsf			INTCON,GIE			;Ativa as interrup��es

	BANK0
	bsf			LED_OERR			;Inicia o programa com o led setado (apagado) para OK


;Fim do Meu setup

;****************************************************************************
;*							INICIALIZA��O DAS VARI�VEIS						*
;****************************************************************************

	movlw		.0
	movwf		CONTADORLED_OERR	;Inicializa o contador do LED_OERR

;****************************************************************************
;*							CORPO DA ROTINA PRINCIPAL						*
;****************************************************************************

MAIN
	;CORPO DA ROTINA PRINCIPAL

	movlw		B'10101010'		;Carrega a mem�ria RAM com esse valor
	movwf		0x22			;para eu poder testar as rotinas de leitura/escrita de bit
								;no pino definido por saida.

	movlw		.2				;Carrega o W com o valor necess�rio
								;para a l�gica do PCL.

bit00
	SAIDABIT 0x22,0x23,8,bit00
bit0
	btfss		0x22,0
	addwf		PCL,1
	bsf			saida
	goto		proximo_bit
	bcf			saida
	nop
	nop

proximo_bit
	btfss		0x22,1
	addwf		PCL,1
	bsf			saida
	goto		proximo_bit
	bcf			saida
	nop
	nop

	GOTO 		MAIN

;****************************************************************************
;*							FIM DO PROGRAMA									*
;****************************************************************************


	END							;INDICA O FIM DO ARQUIVO C�DIGO-FONTE
	

;Modelo de estrutura��o de c�dido baseado no exemplo do livro "Desbravando o PIC"
