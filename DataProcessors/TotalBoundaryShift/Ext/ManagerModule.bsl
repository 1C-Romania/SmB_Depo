#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Shifts the limits of totals.
Procedure RunCommand(CommandParameters, StorageAddress) Export
	SetPrivilegedMode(True);
	TotalsAndAggregateManagementService.SetTotalsPeriod();
	Result = New Structure;
	StandardSubsystemsClientServer.DisplayNotification(
		Result,
		NStr("en = 'Application optimization'"),
		NStr("en = 'is successfully completed'"),
		PictureLib.Successfully32);
	PutToTempStorage(Result, StorageAddress);
EndProcedure

#EndRegion

#EndIf
