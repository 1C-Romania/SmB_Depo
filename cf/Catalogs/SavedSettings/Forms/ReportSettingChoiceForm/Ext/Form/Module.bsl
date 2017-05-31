#Region FormHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ShowAllUsersSettings(Command)	
	SetOwnerFieldFilterUse(False);	
	Items.FormShowOnlyCurrentUserSettings.Visible = True;
	Items.FormShowAllUsersSetting.Visible = False;
EndProcedure

&AtClient
Procedure ShowOnlyCurrentUserSettings(Command)
	SetOwnerFieldFilterUse(True);
	Items.FormShowOnlyCurrentUserSettings.Visible = False;
	Items.FormShowAllUsersSetting.Visible = True;
EndProcedure

#EndRegion

#Region Other

&AtClient
Procedure SetOwnerFieldFilterUse(Val Use)
	
	FilterSetsArray = New Array;
	FilterSetsArray.Add(List.SettingsComposer.FixedSettings.Filter.Items);
	FilterSetsArray.Add(List.Filter.Items);
	
	For Each FilterSetsArrayItem In FilterSetsArray Do
		
		For Each FilterItem In FilterSetsArrayItem Do
			
			If FilterItem.LeftValue = New DataCompositionField("Owner") Then
				
				FilterItem.Use = Use;
				
			EndIf;	
			
		EndDo;	
		
	EndDo;
	
	RefreshDataRepresentation();
	
EndProcedure	


#EndRegion



