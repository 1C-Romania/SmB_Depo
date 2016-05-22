////////////////////////////////////////////////////////////////////////////////
// Subsystem "Banks".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Displays a notification on the need to update banks classifier.
//
Procedure WorkWithBanksWithdrawNotificationOfIrrelevance() Export
	WorkWithBanksClient.NotifyClassifierOutOfDate();
EndProcedure

#EndRegion
