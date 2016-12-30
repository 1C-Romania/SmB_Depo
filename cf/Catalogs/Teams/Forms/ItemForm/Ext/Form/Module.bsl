#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Constants.FunctionalOptionUseJobSharing.Get() Then
		
		If Items.Find("ContentEmployeeCode") <> Undefined Then	
			
			Items.ContentEmployeeCode.Visible = False;		
			
		EndIf;
		
	EndIf; 	
	
EndProcedure

#EndRegion