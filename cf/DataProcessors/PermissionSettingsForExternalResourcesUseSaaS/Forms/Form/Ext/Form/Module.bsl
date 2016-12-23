
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Raise NStr("en='DataProcessor is not intended for interactive use!';ru='Обработка не предназначена для интерактивного использования!'");
	
EndProcedure














