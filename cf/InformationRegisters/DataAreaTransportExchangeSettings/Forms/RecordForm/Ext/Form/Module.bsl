
#Region FormCommandsHandlers

&AtClient
Procedure OpenCommonTrasportSettings(Command)
	
	Filter              = New Structure("CorrespondentEndPoint", Record.CorrespondentEndPoint);
	FillingValues = New Structure("CorrespondentEndPoint", Record.CorrespondentEndPoint);
	
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "DataAreasTransportExchangeSettings", ThisObject);
	
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
