#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnWrite(Cancel)
	
	UseService = Constants.UseCounterpartiesVerification.Get();
	
	// Enable/disable reg job, depending on user's selection.
	ScheduledJob = ScheduledJobs.FindPredefined(
		Metadata.ScheduledJobs.CounterpartiesCheck);
	ScheduledJob.Use = UseService;
	ScheduledJob.Write();

EndProcedure

#EndIf