////////////////////////////////////////////////////////////////////////////////
// DataAreasBackup.
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Offers the user to create a backup.
//
Procedure OfferUserToBackup() Export
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().DataAreasBackup Then
		
		FormName = "CommonForm.BackupCreation";
		
	Else
		
		FormName = "CommonForm.DataExport";
		
	EndIf;
	
	OpenForm(FormName);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Handlers of SSL subsystems internal events.

// Checks possibility of backup in user mode.
//
// Parameters:
//  Result - Boolean (return value).
//
Procedure WhenVerifyingBackupPossibilityInUserMode(Result) Export
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().DataSeparationEnabled Then
		
		Result = True;
		
	EndIf;
	
EndProcedure

// Appears when the user is offered to create a backup.
//
Procedure WhenUserIsOfferedToBackup() Export
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().DataSeparationEnabled Then
		
		OfferUserToBackup();
		
	EndIf;
	
EndProcedure

#EndRegion