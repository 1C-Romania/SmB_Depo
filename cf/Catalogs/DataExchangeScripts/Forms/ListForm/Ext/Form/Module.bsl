
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



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
