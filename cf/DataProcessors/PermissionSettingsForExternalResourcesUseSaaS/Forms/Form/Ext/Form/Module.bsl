
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Raise NStr("en='DataProcessor is not intended for interactive use!';ru='Обработка не предназначена для интерактивного использования!'");
	
EndProcedure



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
