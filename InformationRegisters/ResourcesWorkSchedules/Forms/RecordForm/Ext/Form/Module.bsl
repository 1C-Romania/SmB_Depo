// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("WorkSchedule") Then
		Record.WorkSchedule = Parameters.WorkSchedule;
	EndIf;
	
EndProcedure // OnCreateAtServer()
