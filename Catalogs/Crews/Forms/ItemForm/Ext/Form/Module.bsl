
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Constants.FunctionalOptionUseJobSharing.Get() Then
		If Items.Find("ContentEmployeeCode") <> Undefined Then		
			Items.ContentEmployeeCode.Visible = False;		
		EndIf;
	EndIf; 	
	
EndProcedure
