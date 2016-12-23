
#Region FormCommandsHandlers

&AtClient
Procedure EnableDisableScheduledJob(Command)
	
	SelectedRows = Items.List.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	EnableDisableScheduledJobAtServer(SelectedRows, Not CurrentData.UseScheduledJob);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure EnableDisableScheduledJobAtServer(SelectedRows, UseScheduledJob)
	
	For Each RowData IN SelectedRows Do
		
		If RowData.DeletionMark Then
			Continue;
		EndIf;
		
		SettingsObject = RowData.Ref.GetObject();
		SettingsObject.UseScheduledJob = UseScheduledJob;
		SettingsObject.Write();
		
	EndDo;
	
	// update data of the list
	Items.List.Refresh();
	
EndProcedure

#EndRegion














