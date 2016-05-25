
#Region FormEventsHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Object.Predefined Then
		ReadOnly = True;
	EndIf;
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Catalog.WorldCountries.Update", Object.Ref, ThisObject);
EndProcedure

#EndRegion



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
