
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Raise NStr("en='Data processor is not for interactive use.';ru='Обработка не предназначена для интерактивного использования!'");
	
EndProcedure
