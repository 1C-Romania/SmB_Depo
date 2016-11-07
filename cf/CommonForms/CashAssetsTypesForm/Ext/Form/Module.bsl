
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Selection = Enums.CashAssetTypes.Noncash;
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	Close(Selection);
	
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
