#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If DeletionMark Then
		
		UseScheduledJob = False;
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Delete the scheduled job if necessary.
	If DeletionMark Then
		
		DeleteScheduledJob(Cancel);
		
	EndIf;
	
	// Updating the platform cache for
	// reading actual data exchenge script settings by procedure DataExchangeReUse.GetExchangeSettingStructure.
	RefreshReusableValues();
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	ScheduledJobGUID = "";
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DeleteScheduledJob(Cancel);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Performs scheduled job deletion.
//
// Parameters:
//  Cancel                     - Boolean - Failure flag. If errors occur while executing the
//                                       procedure, check box of denial is set to the True value.
//  ScheduledJobObject - object of the scheduled job that is to be deleted.
// 
Procedure DeleteScheduledJob(Cancel)
	
	SetPrivilegedMode(True);
	
	// Define the scheduled job.
	ScheduledJobObject = DataExchangeServerCall.FindScheduledJobByParameter(ScheduledJobGUID);
	
	If ScheduledJobObject <> Undefined Then
		
		Try
			ScheduledJobObject.Delete();
		Except
			MessageString = NStr("en='An error occurred while deleting scheduled job: %1';ru='Ошибка при удалении регламентного задания: %1'");
			MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, BriefErrorDescription(ErrorInfo()));
			DataExchangeServer.ShowMessageAboutError(MessageString, Cancel);
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
