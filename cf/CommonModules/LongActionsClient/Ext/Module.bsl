////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Long server operations work support in web client.
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Fills the structure of parameters with default values.
// 
// Parameters:
//  IdleHandlerParameters - Structure - filled with default values. 
//
// 
Procedure InitIdleHandlerParameters(IdleHandlerParameters) Export
	
	IdleHandlerParameters = New Structure(
		"MinInterval,MaxInterval,CurrentInterval,IntervalIncreaseCoefficient", 1, 15, 1, 1.4);
	
EndProcedure

// Fills the structure of parameters with new calculated values.
// 
// Parameters:
//  IdleHandlerParameters - Structure - filled with calculated values. 
//
// 
Procedure UpdateIdleHandlerParameters(IdleHandlerParameters) Export
	
	IdleHandlerParameters.CurrentInterval = IdleHandlerParameters.CurrentInterval * IdleHandlerParameters.IntervalIncreaseCoefficient;
	If IdleHandlerParameters.CurrentInterval > IdleHandlerParameters.MaxInterval Then
		IdleHandlerParameters.CurrentInterval = IdleHandlerParameters.MaxInterval;
	EndIf;
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with long operation form.
//

// Opens the form indicating a long operation.
// 
// Parameters:
//  FormOwner  - ManagedForm - the form from which the opening is executed. 
//  JobID      - UUID        - The ID of the background job.
//
// Returns:
//  ManagedForm     - ref to the open form.
// 
Function OpenLongOperationForm(Val FormOwner, Val JobID) Export
	
	LongOperationForm = LongActionsClientReUse.LongOperationForm();
	If LongOperationForm.IsOpen() Then
		LongOperationForm = OpenForm(
			"CommonForm.LongOperation",
			New Structure("JobID", JobID), 
			FormOwner);
	Else
		LongOperationForm.FormOwner        = FormOwner;
		LongOperationForm.JobID = JobID;
		LongOperationForm.Open();
	EndIf;
	
	Return LongOperationForm;
	
EndFunction

// Closes the form indicating a long operation.
// 
// Parameters:
//  RefToForm - ManagedForm - ref to the form indicating a long operation. 
//
Procedure CloseLongOperationForm(LongOperationForm) Export
	
	If TypeOf(LongOperationForm) = Type("ManagedForm") Then
		If LongOperationForm.IsOpen() Then
			LongOperationForm.Close();
		EndIf;
	EndIf;
	LongOperationForm = Undefined;
	
EndProcedure

#EndRegion
