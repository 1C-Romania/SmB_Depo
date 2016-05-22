
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentJournalBankDocuments");
	// End StandardSubsystems.PerformanceEstimation
	
	OpenForm("DocumentJournal.BankDocuments.ListForm", , CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
