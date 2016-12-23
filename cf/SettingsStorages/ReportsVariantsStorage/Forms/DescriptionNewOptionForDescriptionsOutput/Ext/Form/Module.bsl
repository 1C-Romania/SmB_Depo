
#Region FormCommandsHandlers

&AtClient
Procedure DisableNow(Command)
	UpdateParameters = New Structure;
	UpdateParameters.Insert("ShowToolTips", 0);
	ReportsVariantsClient.OpenFormsRefresh(UpdateParameters);
	Close();
EndProcedure

#EndRegion














