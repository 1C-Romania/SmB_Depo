
#Region FormCommandsHandlers

&AtClient
Procedure OpenCommonTrasportSettings(Command)
	
	Filter              = New Structure("CorrespondentEndPoint", Record.CorrespondentEndPoint);
	FillingValues = New Structure("CorrespondentEndPoint", Record.CorrespondentEndPoint);
	
	DataExchangeClient.OpenInformationRegisterRecordFormByFilter(Filter, FillingValues, "DataAreasTransportExchangeSettings", ThisObject);
	
EndProcedure

#EndRegion














