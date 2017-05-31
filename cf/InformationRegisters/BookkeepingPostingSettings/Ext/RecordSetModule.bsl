
Procedure BeforeWrite(Cancel, Replacing)
	
	For Each Record In ThisObject Do
		
		If Record.Object = Undefined Then 
			Alerts.AddAlert(Nstr("en='Document type should be selected!';pl='Nalezy wybrać typ dokumentu!';ru='Выберите тип документа!'"),Enums.AlertType.Error,Cancel);
			Break;
		EndIf;
		
		If ValueIsNotFilled(Record.BookkeepingPostingType) Then 
			Alerts.AddAlert(Nstr("en='Bookkeeping posting type should be selected!';pl='Nalezy wybrać typ księgowania dla dokumentu!';ru='Выберите способ проведения документа!'"),Enums.AlertType.Error,Cancel);
			break;
		EndIf;
		
	EndDo;
	
EndProcedure
