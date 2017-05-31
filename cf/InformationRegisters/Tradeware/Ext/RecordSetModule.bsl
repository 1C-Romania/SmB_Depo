Procedure BeforeWrite(Cancel, Replacing)

	If DataExchange.Load Then
		Return;
	EndIf;

	Record = Undefined;
	For Each Record In ThisObject Do
		If NOT ValueIsFilled(Record.Identifier) AND NOT ValueIsFilled(Record.Model)
			 AND NOT ValueIsFilled(Record.Parameters) AND NOT ValueIsFilled(Record.Computer) Then
			Alerts.AddAlert(Nstr("en='Not specified service processor!';pl='Obróbka serwisowa nie jest określiona!'; ru='Не выбрана сервисная обработка!'"),Enums.AlertType.Error,Cancel,ThisObject);
			Break;
		EndIf;
		Record.Use = True;
	EndDo;

EndProcedure // BeforeWrite()
