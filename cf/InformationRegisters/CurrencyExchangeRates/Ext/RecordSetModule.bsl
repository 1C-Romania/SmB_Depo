Procedure BeforeWrite(Cancel, Replacing)
	
	For Each Record In ThisObject Do
		
		If Record.ExchangeRate = 0 Then
			Common.ErrorMessage(Nstr("en='Exchange rate can not be 0!';pl='Kurs wymiany nie może być 0!';ru='Обменный курс не может быть 0!'"));
			Cancel = True;
		EndIf;

	EndDo;	
	
EndProcedure