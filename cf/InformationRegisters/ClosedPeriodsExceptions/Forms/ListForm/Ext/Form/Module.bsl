
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Not CommonAtServer.UseMultiCompaniesMode() Then
		
		Items.List.ChildItems.Company.Visible	= False;
		
	EndIf;
	
EndProcedure
