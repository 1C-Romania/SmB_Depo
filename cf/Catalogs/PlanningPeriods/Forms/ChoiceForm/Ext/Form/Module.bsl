
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ExcludeActualPeriod") AND Parameters.ExcludeActualPeriod Then
		List.Parameters.SetParameterValue("ExcludeActualPeriod", True);
	Else
		List.Parameters.SetParameterValue("ExcludeActualPeriod", False);
	EndIf;
		
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
