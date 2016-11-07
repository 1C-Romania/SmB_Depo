
#Region FormCommandsHandlers

&AtClient
Procedure DisableNow(Command)
	UpdateParameters = New Structure;
	UpdateParameters.Insert("ShowToolTips", 0);
	ReportsVariantsClient.OpenFormsRefresh(UpdateParameters);
	Close();
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
