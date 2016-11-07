
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	SynchronizationParameters = New Structure;
	SettingArrayEDF = New Array;
	SettingArrayEDF.Add(CommandExecuteParameters.Source.Object.EDAgreement);
	SynchronizationParameters.Insert("EDFSettingsWithBanks", SettingArrayEDF);
	SynchronizationParameters.Insert("SynchronizationWithBanksCurrentIndex", 0);
	
	ElectronicDocumentsServiceClient.RunExchangeWithBanks(Undefined, SynchronizationParameters);
	
EndProcedure
