
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentJournalCashDocuments");
	// End StandardSubsystems.PerformanceEstimation
	
	OpenForm("DocumentJournal.CashDocuments.ListForm", , CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
