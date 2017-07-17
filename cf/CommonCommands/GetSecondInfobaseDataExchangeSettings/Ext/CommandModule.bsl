
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Cancel = False;
	
	TemporaryStorageAddress = "";
	
	GetSecondInfobaseDataExchangeSettingsAtServer(Cancel, TemporaryStorageAddress, CommandParameter);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("en='Errors occurred when receiving data exchange settings.';ru='Возникли ошибки при получении настроек обмена данными.'"));
		
	Else
		
		GetFile(TemporaryStorageAddress, NStr("en='Data synchronization settings.xml';ru='Настройки синхронизации данных.xml'"), True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure GetSecondInfobaseDataExchangeSettingsAtServer(Cancel, TemporaryStorageAddress, InfobaseNode)
	
	DataExchangeCreationAssistant = DataProcessors.DataExchangeCreationAssistant.Create();
	DataExchangeCreationAssistant.Initialization(InfobaseNode);
	DataExchangeCreationAssistant.RunAssistantParametersDumpIntoTemporaryStorage(Cancel, TemporaryStorageAddress);
	
EndProcedure

#EndRegion
